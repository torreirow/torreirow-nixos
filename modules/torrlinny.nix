{ config, lib, pkgs, ... }:

# Torrlinny notities-web.
#
# Ontsluit de PRIVÉ Hugo-repo torreirow/torrlinny als een strakke, doorzoekbare
# statische site op https://linny.toorren.net (achter Authelia), die automatisch
# herbouwt zodra er naar `main` gepusht is.
#
# Aanpak (epic nixos-anvf + nixos-al4j):
#  - RENDER = de EIGEN web-config van de repo: `hugo --config hugo-web.yaml
#    --configDir doesnotexist`. De repo importeert de gedeelde **linny-web-theme**
#    Hugo-module (github.com/torreirow/linny-web-theme) die geekdoc bundelt + de
#    Linny-layouts (taxonomie-zijbalk, Created/Updated, overzichtspagina's) levert.
#    De build haalt de module met `hugo mod get` (Go in de PATH). Geen eigen
#    overlay meer op malandro — dat zit nu allemaal in de theme.
#  - Runtime-build (systemd oneshot), GEEN nix-derivation: sync (git) -> hugo mod
#    get -> hugo -> ATOMIC SWAP van een symlink -> nginx serveert altijd de vorige
#    goede build bij een fout (keep-last-good).
#  - Trigger = systemd-timer met change-detectie (git fetch + HEAD-compare).
#    (GitHub-webhook is een aparte, latere bean.)

with lib;

let
  cfg = config.services.torrlinny;
  autheliaHelpers = import ./authelia-nginx.nix { inherit lib; };

  repoUrl = "git@github.com:torreirow/torrlinny.git";
  keyPath = config.age.secrets.torrlinny-deploy-key.path;

  buildScript = pkgs.writeShellScript "torrlinny-build" ''
    set -euo pipefail

    WORK="${cfg.dataDir}"
    CHECKOUT="$WORK/checkout"
    BUILDS="$WORK/builds"
    LIVE="$WORK/live"
    RECIPE="hugo=${pkgs.hugo.version};go=${pkgs.go.version}"
    FORCE="''${1:-}"

    export HOME="$WORK"
    export GIT_SSH_COMMAND="ssh -i ${keyPath} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=$WORK/known_hosts"

    # Go / Hugo-module-cache in de (persistente) werkmap. GOPROXY=direct haalt de
    # theme rechtstreeks van GitHub; go.sum (in de repo) borgt de integriteit, dus
    # GOSUMDB uit (geen externe sumdb-afhankelijkheid).
    export GOPATH="$WORK/go"
    export GOMODCACHE="$WORK/go/pkg/mod"
    export GOCACHE="$WORK/gocache"
    export GOPROXY=direct
    export GOSUMDB=off
    export HUGO_CACHEDIR="$WORK/hugo_cache"

    mkdir -p "$BUILDS" "$GOPATH" "$GOCACHE" "$HUGO_CACHEDIR"

    ## 1. sync (VOLLEDIGE clone voor enableGitInfo/.Lastmod) + change-detectie
    if [ ! -d "$CHECKOUT/.git" ]; then
      rm -rf "$CHECKOUT"
      git clone --branch main "${repoUrl}" "$CHECKOUT"
    else
      if [ -f "$CHECKOUT/.git/shallow" ]; then
        git -C "$CHECKOUT" fetch --unshallow origin main || git -C "$CHECKOUT" fetch origin main
      else
        git -C "$CHECKOUT" fetch origin main
      fi
      LOCAL="$(git -C "$CHECKOUT" rev-parse HEAD)"
      REMOTE="$(git -C "$CHECKOUT" rev-parse origin/main)"
      # Skip alleen als content (git HEAD) ÉN het bouw-recept (hugo/go-versie)
      # onveranderd zijn t.o.v. de laatste build.
      if [ "$LOCAL" = "$REMOTE" ] && [ -e "$LIVE" ] && [ "$FORCE" != "--force" ] \
         && [ "$(cat "$WORK/last-build-recipe" 2>/dev/null)" = "$RECIPE" ]; then
        echo "torrlinny: geen wijziging ($LOCAL), build overgeslagen"
        exit 0
      fi
      git -C "$CHECKOUT" reset --hard origin/main
      git -C "$CHECKOUT" clean -fdx
    fi
    REV="$(git -C "$CHECKOUT" rev-parse --short HEAD)"

    ## 2. theme-module ophalen (github.com/torreirow/linny-web-theme, gepind in
    ##    de repo's go.mod/go.sum).
    ( cd "$CHECKOUT" && ${pkgs.hugo}/bin/hugo mod get github.com/torreirow/linny-web-theme )

    ## 3. CLI-output met box-drawing tekens (bv. aws --output table) in code-fences
    ##    wikkelen zodat het als nette monospace-tabel rendert. fence.py komt uit de
    ##    repo. In-place op de (wegwerp-)checkout -> .git blijft -> enableGitInfo/
    ##    .Lastmod werkt. Idempotent (checkout wordt per sync ge-reset). Bron-repo
    ##    blijft ongemoeid (we bouwen in de checkout).
    find "$CHECKOUT/content" -name '*.md' -exec ${pkgs.bash}/bin/bash -c \
      'for f; do ${pkgs.python3}/bin/python3 "'"$CHECKOUT"'/fence.py" < "$f" > "$f.pf" && mv "$f.pf" "$f"; done' _ {} +

    ## 4. bouwen met de web-config (hugo-web.yaml importeert de theme; configDir=
    ##    doesnotexist zodat de Linny-JSON-indexer NIET meelaadt). In een VERSE dir
    ##    zodat de swap atomisch kan.
    DEST="$BUILDS/$REV-$(date +%s)"
    rm -rf "$DEST"
    ${pkgs.hugo}/bin/hugo --source "$CHECKOUT" \
      --config hugo-web.yaml --configDir doesnotexist \
      --baseURL "https://${cfg.domain}/" \
      --minify --destination "$DEST" --logLevel error
    chmod -R a+rX "$DEST"

    ## 5. atomic swap. Faalt de build -> set -e stopt hier vóór -> LIVE (vorige goede
    ##    build) blijft ongewijzigd (keep-last-good).
    ln -sfn "$DEST" "$WORK/live.new"
    mv -Tf "$WORK/live.new" "$LIVE"
    echo "$RECIPE" > "$WORK/last-build-recipe"
    echo "torrlinny: gepubliceerd rev $REV -> $DEST"

    ## 6. prune: bewaar de 3 nieuwste builds
    find "$BUILDS" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' \
      | sort -rn | tail -n +4 | cut -d' ' -f2- | xargs -r rm -rf
  '';

in {
  options.services.torrlinny = {
    enable = mkEnableOption "Torrlinny notities-web (Hugo + linny-web-theme, auto-rebuild)";

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
      description = "Werkmap: checkout, builds, module-cache en de live-symlink.";
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
      description = "Torrlinny: sync + hugo mod get + Hugo build (atomic swap)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      # go: nodig voor `hugo mod get` (Hugo-modules resolven via de Go-toolchain).
      path = with pkgs; [ git openssh coreutils findutils go ];

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
