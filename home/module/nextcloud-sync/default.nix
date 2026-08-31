# home-manager module: headless Nextcloud sync via nextcloudcmd + user-timers
#
# Regelt per user een headless Nextcloud-sync in met `nextcloudcmd` (uit
# pkgs.nextcloud-client). Geen GUI/tray: elke sync is een oneshot
# systemd.user.service die door een systemd.user.timer periodiek wordt
# getriggerd.
#
# Credentials: NOOIT in de nix-store. `nextcloudcmd --non-interactive` leest
# $NC_USER en $NC_PASSWORD uit de environment; die komen uit een HANDMATIG
# aangemaakt EnvironmentFile (default ~/.config/nextcloud-sync/credentials,
# mode 0600). Zie README.md. Gebruik een Nextcloud APP-PASSWORD, nooit het
# hoofdwachtwoord.
{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.services.nextcloud-sync;

  # Expandeer een leidende ~ naar de absolute home-dir (systemd expandeert ~
  # niet in ExecStart-argumenten).
  normalizePath = p:
    if p == "~" then config.home.homeDirectory
    else if hasPrefix "~/" p then "${config.home.homeDirectory}/${removePrefix "~/" p}"
    else p;

  configDir = "${config.home.homeDirectory}/.config/nextcloud-sync";

  syncModule = { name, ... }: {
    options = {
      serverUrl = mkOption {
        type = types.str;
        example = "https://cloud.example.com";
        description = "Basis-URL van de Nextcloud-server.";
      };
      localPath = mkOption {
        type = types.str;
        example = "~/Nextcloud";
        description = ''
          Lokale map die gesynct wordt. Een leidende `~/` wordt geëxpandeerd
          naar de home-dir. De map wordt aangemaakt als hij nog niet bestaat.
        '';
      };
      remotePath = mkOption {
        type = types.str;
        default = "/";
        description = "Remote map op de server (via `--path`). Default de hele account-root.";
      };
      interval = mkOption {
        type = types.str;
        default = "10min";
        example = "15min";
        description = ''
          Sync-interval als systemd-tijdspanne. Wordt gebruikt als
          `OnUnitActiveSec` (dus: interval ná afloop van de vorige run, zodat
          een trage sync niet overlapt met de volgende).
        '';
      };
      excludeFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optioneel pad naar een nextcloudcmd exclude-list (`--exclude`).";
      };
      trust = mkOption {
        type = types.bool;
        default = false;
        description = "Vertrouw het SSL-certificaat onvoorwaardelijk (`--trust`). Alleen voor self-signed test-servers.";
      };
      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Extra losse argumenten voor `nextcloudcmd`.";
      };
    };
  };

  # Bouw de ExecStart-commandline voor één sync.
  mkExecStart = name: sync:
    let
      localPath = normalizePath sync.localPath;
      stateDir = "${configDir}/state/${name}";
      args =
        [ "${cfg.package}/bin/nextcloudcmd" "--non-interactive" "--silent" ]
        ++ optional sync.trust "--trust"
        ++ optionals (sync.remotePath != "/") [ "--path" sync.remotePath ]
        ++ optionals (sync.excludeFile != null) [ "--exclude" (normalizePath sync.excludeFile) ]
        ++ [ "--confdir" stateDir ]
        ++ sync.extraArgs
        ++ [ localPath sync.serverUrl ];
    in
    escapeShellArgs args;

  # ExecStartPre: valideer credentials + maak de lokale map en state-dir aan.
  mkPreStart = name: sync:
    let
      localPath = normalizePath sync.localPath;
      stateDir = "${configDir}/state/${name}";
    in
    pkgs.writeShellScript "nextcloud-sync-${name}-pre" ''
      set -eu
      if [ ! -r "${cfg.credentialsFile}" ]; then
        echo "nextcloud-sync (${name}): credentials-bestand '${cfg.credentialsFile}' ontbreekt of is onleesbaar." >&2
        echo "Maak het handmatig aan (mode 0600) met NC_USER en NC_PASSWORD (een Nextcloud app-password)." >&2
        echo "Zie ~/.config/nextcloud-sync/credentials.example of de module-README." >&2
        exit 1
      fi
      if [ -z "''${NC_USER:-}" ] || [ -z "''${NC_PASSWORD:-}" ]; then
        echo "nextcloud-sync (${name}): NC_USER en/of NC_PASSWORD is leeg in '${cfg.credentialsFile}'." >&2
        exit 1
      fi
      mkdir -p "${localPath}" "${stateDir}"
    '';

in
{
  options.services.nextcloud-sync = {
    enable = mkEnableOption "headless Nextcloud-sync via nextcloudcmd + systemd user-timers";

    package = mkOption {
      type = types.package;
      default = pkgs.nextcloud-client;
      defaultText = literalExpression "pkgs.nextcloud-client";
      description = "Package die `nextcloudcmd` levert.";
    };

    credentialsFile = mkOption {
      type = types.str;
      default = "${configDir}/credentials";
      defaultText = literalExpression ''"''${config.home.homeDirectory}/.config/nextcloud-sync/credentials"'';
      description = ''
        Pad naar een systemd EnvironmentFile met `NC_USER=` en `NC_PASSWORD=`
        (een Nextcloud app-password). Dit bestand moet je ZELF aanmaken met
        mode 0600 — het wordt bewust NIET door Nix beheerd, zodat het
        wachtwoord nooit in de wereld-leesbare nix-store belandt.
      '';
    };

    syncs = mkOption {
      type = types.attrsOf (types.submodule syncModule);
      default = { };
      example = literalExpression ''
        {
          docs = {
            serverUrl = "https://cloud.example.com";
            localPath = "~/Nextcloud";
            interval = "10min";
          };
        }
      '';
      description = "Sync-paren, per naam. Elk paar krijgt een eigen oneshot-service + timer.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # Voorbeeld-credentialsbestand (placeholders, geen geheim) — geeft ook
    # meteen de map ~/.config/nextcloud-sync/.
    home.file.".config/nextcloud-sync/credentials.example".text = ''
      # Kopieer naar 'credentials' (mode 0600) en vul in met een Nextcloud app-password.
      #   install -m600 /dev/stdin ~/.config/nextcloud-sync/credentials <<'EOF'
      # Gebruik NOOIT je hoofdwachtwoord; maak een app-password aan in
      # Nextcloud > Instellingen > Beveiliging > Apparaten & sessies.
      NC_USER=your-username
      NC_PASSWORD=your-app-password
    '';

    systemd.user.services = mapAttrs'
      (name: sync: nameValuePair "nextcloud-sync-${name}" {
        Unit = {
          Description = "Nextcloud sync (${name})";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };
        Service = {
          Type = "oneshot";
          # '-' => optioneel: ontbreken van het bestand faalt de unit niet
          # vóór ExecStartPre, zodat die een nette foutmelding kan geven.
          EnvironmentFile = "-${cfg.credentialsFile}";
          ExecStartPre = "${mkPreStart name sync}";
          ExecStart = mkExecStart name sync;
        };
      })
      cfg.syncs;

    systemd.user.timers = mapAttrs'
      (name: sync: nameValuePair "nextcloud-sync-${name}" {
        Unit.Description = "Timer voor Nextcloud sync (${name})";
        Timer = {
          OnActiveSec = "2min";           # eerste run kort na login
          OnUnitActiveSec = sync.interval; # daarna: interval ná vorige run
        };
        Install.WantedBy = [ "timers.target" ];
      })
      cfg.syncs;
  };
}
