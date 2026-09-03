{ config, lib, pkgs, ... }:

# Torrlinny notities-web.
#
# Ontsluit de PRIVÉ Hugo-repo torreirow/torrlinny als een strakke, doorzoekbare
# statische site op https://linny.toorren.net (achter Authelia), die automatisch
# herbouwt zodra er naar `main` gepusht is.
#
# Aanpak (epic nixos-anvf):
#  - RENDER = de EIGEN web-config van de repo: `hugo --config hugo-web.yaml
#    --configDir doesnotexist` met het geekdoc-thema (submodule) — exact zoals
#    `start-web.sh` lokaal. GeekDoc levert de zijbalk/file-tree, ingebouwde zoek en
#    de taxonomie-menu's (customer/project/type/tags). Geen eigen overlay/Pagefind.
#  - Runtime-build (systemd oneshot), GEEN nix-derivation: sync (git + submodules)
#    -> hugo -> ATOMIC SWAP van een symlink -> nginx serveert altijd de vorige goede
#    build bij een fout (keep-last-good).
#  - Trigger = systemd-timer met change-detectie (git fetch + HEAD-compare).
#    (GitHub-webhook is een aparte, latere bean.)

with lib;

let
  cfg = config.services.torrlinny;
  autheliaHelpers = import ./authelia-nginx.nix { inherit lib; };

  repoUrl = "git@github.com:torreirow/torrlinny.git";
  keyPath = config.age.secrets.torrlinny-deploy-key.path;

  # Overlay bovenop de geekdoc-web-build (torrlinny-repo blijft ongemoeid): wordt bij
  # de build in de checkout gelegd en overschrijft/aanvult het thema.
  #  - layouts/partials/page-metadata.html : Created (crdate) + Updated (git .Lastmod)
  #  - layouts/partials/menu.html          : "Overzichten"-blok in de zijbalk
  #  - layouts/_default/noteslist.html     : paginated overzicht (op titel/datum)
  #  - content/notes-by-{title,date}/      : de twee overzichtspagina's
  #  - web-extra.yaml                       : enableGitInfo (voor .Lastmod)
  overlayDir = ./torrlinny/overlay;

  buildScript = pkgs.writeShellScript "torrlinny-build" ''
    set -euo pipefail

    WORK="${cfg.dataDir}"
    CHECKOUT="$WORK/checkout"
    BUILDS="$WORK/builds"
    LIVE="$WORK/live"
    RECIPE="${pkgs.hugo}:${overlayDir}"
    FORCE="''${1:-}"

    export HOME="$WORK"
    export GIT_SSH_COMMAND="ssh -i ${keyPath} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=$WORK/known_hosts"

    mkdir -p "$BUILDS"

    ## 1. sync (VOLLEDIGE clone + submodules voor het geekdoc-thema) + change-detectie
    if [ ! -d "$CHECKOUT/.git" ]; then
      rm -rf "$CHECKOUT"
      git clone --recurse-submodules --branch main "${repoUrl}" "$CHECKOUT"
    else
      if [ -f "$CHECKOUT/.git/shallow" ]; then
        git -C "$CHECKOUT" fetch --unshallow origin main || git -C "$CHECKOUT" fetch origin main
      else
        git -C "$CHECKOUT" fetch origin main
      fi
      LOCAL="$(git -C "$CHECKOUT" rev-parse HEAD)"
      REMOTE="$(git -C "$CHECKOUT" rev-parse origin/main)"
      # Skip alleen als content (git HEAD) ÉN het bouw-recept (hugo-versie)
      # onveranderd zijn t.o.v. de laatste build.
      if [ "$LOCAL" = "$REMOTE" ] && [ -e "$LIVE" ] && [ "$FORCE" != "--force" ] \
         && [ "$(cat "$WORK/last-build-recipe" 2>/dev/null)" = "$RECIPE" ]; then
        echo "torrlinny: geen wijziging ($LOCAL), build overgeslagen"
        exit 0
      fi
      git -C "$CHECKOUT" reset --hard origin/main
      git -C "$CHECKOUT" submodule update --init --recursive
    fi
    REV="$(git -C "$CHECKOUT" rev-parse --short HEAD)"

    ## 2. bouwen met de web-config (identiek aan start-web.sh: hugo-web.yaml +
    ##    geekdoc-thema; configDir=doesnotexist zodat de Linny-JSON-config NIET meelaadt).
    ##    Bouwt in een VERSE dir zodat de swap atomisch kan.
    # Overlay in de checkout leggen (layouts overriden/aanvullen + overzichtspagina's).
    chmod -R u+w "$CHECKOUT/layouts" "$CHECKOUT/content" 2>/dev/null || true
    cp -rf ${overlayDir}/layouts/. "$CHECKOUT/layouts/"
    cp -rf ${overlayDir}/content/. "$CHECKOUT/content/"

    DEST="$BUILDS/$REV-$(date +%s)"
    rm -rf "$DEST"
    ${pkgs.hugo}/bin/hugo --source "$CHECKOUT" \
      --config hugo-web.yaml,${overlayDir}/web-extra.yaml --configDir doesnotexist \
      --baseURL "https://${cfg.domain}/" \
      --minify --destination "$DEST" --logLevel error
    chmod -R a+rX "$DEST"

    ## 3. atomic swap. Faalt de build -> set -e stopt hier vóór -> LIVE (vorige goede
    ##    build) blijft ongewijzigd (keep-last-good).
    ln -sfn "$DEST" "$WORK/live.new"
    mv -Tf "$WORK/live.new" "$LIVE"
    echo "$RECIPE" > "$WORK/last-build-recipe"
    echo "torrlinny: gepubliceerd rev $REV -> $DEST"

    ## 4. prune: bewaar de 3 nieuwste builds
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
