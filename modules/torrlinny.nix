{ config, lib, pkgs, ... }:

# Torrlinny notities-web.
#
# Ontsluit de PRIVÉ Hugo-repo torreirow/torrlinny als een strakke, doorzoekbare
# statische site op https://linny.toorren.net (achter Authelia), die automatisch
# herbouwt zodra er naar `main` gepusht is.
#
# Aanpak (uit /opsx:explore, epic nixos-anvf):
#  - RENDER = Hugo, met een OVERLAY-frontend (modules/torrlinny/overlay/): een
#    zelfstandige Hugo-site (eigen config + layouts + css) die ALLEEN torrlinny's
#    content/ inleest. De content-repo blijft ongemoeid (geen PaperMod/submodules).
#  - ZOEK/FACET = Pagefind (client-side): full-text + facet-filters op de
#    taxonomieën (customer/project/type/tag/owner/subject/doctype) + datum-sort.
#  - Runtime-build (systemd oneshot), GEEN nix-derivation: sync -> hugo -> pagefind
#    -> ATOMIC SWAP van een symlink -> nginx serveert altijd de vorige goede build
#    bij een fout (keep-last-good).
#  - Trigger = systemd-timer met change-detectie (git fetch + HEAD-compare).
#    (GitHub-webhook is een aparte, latere bean.)

with lib;

let
  cfg = config.services.torrlinny;
  autheliaHelpers = import ./authelia-nginx.nix { inherit lib; };

  overlay = ./torrlinny/overlay;
  repoUrl = "git@github.com:torreirow/torrlinny.git";
  keyPath = config.age.secrets.torrlinny-deploy-key.path;

  buildScript = pkgs.writeShellScript "torrlinny-build" ''
    set -euo pipefail

    WORK="${cfg.dataDir}"
    CHECKOUT="$WORK/checkout"
    BUILDROOT="$WORK/buildroot"
    BUILDS="$WORK/builds"
    LIVE="$WORK/live"
    FORCE="''${1:-}"

    export HOME="$WORK"
    export GIT_SSH_COMMAND="ssh -i ${keyPath} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=$WORK/known_hosts"

    mkdir -p "$BUILDS"

    ## 1. sync + change-detectie
    if [ ! -d "$CHECKOUT/.git" ]; then
      rm -rf "$CHECKOUT"
      git clone --depth 1 --branch main "${repoUrl}" "$CHECKOUT"
    else
      git -C "$CHECKOUT" fetch --depth 1 origin main
      LOCAL="$(git -C "$CHECKOUT" rev-parse HEAD)"
      REMOTE="$(git -C "$CHECKOUT" rev-parse origin/main)"
      if [ "$LOCAL" = "$REMOTE" ] && [ -e "$LIVE" ] && [ "$FORCE" != "--force" ]; then
        echo "torrlinny: geen wijziging ($LOCAL), build overgeslagen"
        exit 0
      fi
      git -C "$CHECKOUT" reset --hard origin/main
    fi
    REV="$(git -C "$CHECKOUT" rev-parse --short HEAD)"

    ## 2. overlay + content samenstellen tot een Hugo-project
    rm -rf "$BUILDROOT"
    mkdir -p "$BUILDROOT"
    cp ${overlay}/hugo.toml "$BUILDROOT/"
    cp -r ${overlay}/layouts "$BUILDROOT/layouts"
    cp -r ${overlay}/static "$BUILDROOT/static"
    cp -r "$CHECKOUT/content" "$BUILDROOT/content"
    chmod -R u+w "$BUILDROOT"

    ## 3. bouwen in een VERSE dir (voorbereiding atomic swap)
    DEST="$BUILDS/$REV-$(date +%s)"
    rm -rf "$DEST"
    ${pkgs.hugo}/bin/hugo --source "$BUILDROOT" --destination "$DEST" --minify --logLevel error
    ${pkgs.pagefind}/bin/pagefind --site "$DEST" >/dev/null
    chmod -R a+rX "$DEST"

    ## 4. atomic swap. Faalt stap 3 -> set -e stopt hier vóór -> LIVE (vorige goede
    ##    build) blijft ongewijzigd (keep-last-good).
    ln -sfn "$DEST" "$WORK/live.new"
    mv -Tf "$WORK/live.new" "$LIVE"
    echo "torrlinny: gepubliceerd rev $REV -> $DEST"

    ## 5. prune: bewaar de 3 nieuwste builds
    find "$BUILDS" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' \
      | sort -rn | tail -n +4 | cut -d' ' -f2- | xargs -r rm -rf
  '';

in {
  options.services.torrlinny = {
    enable = mkEnableOption "Torrlinny notities-web (Hugo + Pagefind, auto-rebuild)";

    domain = mkOption {
      type = types.str;
      default = "linny.toorren.net";
      description = "Domein waarop de site geserveerd wordt (achter Authelia).";
    };

    acmeHost = mkOption {
      type = types.str;
      default = "toorren.net";
      description = "ACME-host voor het (wildcard) TLS-certificaat.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/torrlinny";
      description = "Werkmap: checkout, builds en de live-symlink.";
    };

    user = mkOption {
      type = types.str;
      default = "torrlinny";
      description = "Service-user voor sync + build.";
    };

    interval = mkOption {
      type = types.str;
      default = "3min";
      description = "Poll-interval van de rebuild-timer (change-detectie voorkomt nodeloze builds).";
    };
  };

  config = mkIf cfg.enable {
    ###### Deploy key (read-only) voor de privé-repo ######
    age.secrets.torrlinny-deploy-key = {
      file = ../secrets/torrlinny-deploy-key.age;
      path = "/run/agenix/torrlinny-deploy-key";
      owner = cfg.user;
      mode = "0400";
    };

    ###### User + werkmap ######
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
      home = cfg.dataDir;
      # createHome NIET gebruiken: dat forceert 0700 op de werkmap en blokkeert nginx.
      # De werkmap wordt via tmpfiles op 0750 (groep-traverseerbaar) gezet.
      createHome = false;
      description = "Torrlinny web build user";
    };
    users.groups.${cfg.user} = { };

    # nginx moet de gebouwde site kunnen lezen -> lid van de torrlinny-groep
    # (zelfde patroon als de magister-module).
    users.users.nginx.extraGroups = [ cfg.user ];

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.user} -"
      "z ${cfg.dataDir} 0750 ${cfg.user} ${cfg.user} -"
      "d ${cfg.dataDir}/builds 0750 ${cfg.user} ${cfg.user} -"
    ];

    ###### Build-service (oneshot) ######
    systemd.services.torrlinny-build = {
      description = "Torrlinny: sync + Hugo + Pagefind build (atomic swap)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = with pkgs; [ git openssh coreutils findutils ];

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.user;
        # 'keys' nodig om /run/keys (root:keys 0750) te betreden en zo de agenix
        # deploy-key te kunnen lezen (zelfde patroon als formrelay).
        SupplementaryGroups = [ "keys" ];
        ExecStart = "${buildScript}";

        # Security hardening — read-only observatie behalve de eigen werkmap.
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
      };
    };

    ###### Timer met change-detectie ######
    systemd.timers.torrlinny-build = {
      description = "Torrlinny periodieke rebuild (change-detectie)";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = cfg.interval;
        Persistent = true;
        Unit = "torrlinny-build.service";
      };
    };

    ###### Nginx: serveer de live static-map achter Authelia ######
    services.nginx.virtualHosts.${cfg.domain} = {
      forceSSL = true;
      useACMEHost = cfg.acmeHost;
      root = "${cfg.dataDir}/live";

      locations."/authelia" = autheliaHelpers.autheliaVerifyLocation;

      locations."/" = {
        tryFiles = "$uri $uri/ =404";
        extraConfig = autheliaHelpers.autheliaAuthConfig;
      };
    };
  };
}
