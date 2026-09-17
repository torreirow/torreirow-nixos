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
  stateDir = "${config.home.homeDirectory}/.local/state/nextcloud-sync";

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
  #
  # LET OP: bewust GEEN `--confdir`. In nextcloud-client 4.0.8 zorgt `--confdir`
  # ervoor dat nextcloudcmd enkel de usage-tekst print en stopt (exit 0, geen
  # sync) — een parser-bug in die vlag. Zonder `--confdir` gebruikt nextcloudcmd
  # zijn default config-dir en synct het correct.
  #
  # LET OP 2: `--silent` staat bewust NIET meer standaard aan. Met die vlag
  # schrijft nextcloudcmd niets naar de journal, ook niet bij een fout. Daardoor
  # bleef deze sync van 2026-09-09 tot 2026-09-16 onopgemerkt kapot: 419
  # mislukte runs, nul geslaagde, en in `journalctl` alleen "Failed to start"
  # zonder enige aanwijzing waarom. De oorzaak (een verlopen wachtwoord, en
  # daarna HTTP 429 brute-force-throttling) was pas zichtbaar door het commando
  # handmatig zonder `--silent` te draaien. Zet `quiet = true` als je de
  # uitvoer per se kwijt wilt.
  mkExecStart = name: sync:
    let
      localPath = normalizePath sync.localPath;
      args =
        [ "${cfg.package}/bin/nextcloudcmd" "--non-interactive" ]
        ++ optional cfg.quiet "--silent"
        ++ optional sync.trust "--trust"
        ++ optionals (sync.remotePath != "/") [ "--path" sync.remotePath ]
        ++ optionals (sync.excludeFile != null) [ "--exclude" (normalizePath sync.excludeFile) ]
        ++ sync.extraArgs
        ++ [ localPath sync.serverUrl ];
    in
    escapeShellArgs args;

  # ExecStartPre: valideer credentials + maak de lokale map aan.
  mkPreStart = name: sync:
    let
      localPath = normalizePath sync.localPath;
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
      mkdir -p "${localPath}"
      mkdir -p "${stateDir}"
    '';

  # Het succesmoment van een sync, als mtime van een leeg bestand.
  #
  # Wordt aangeraakt via `ExecStartPost=`, en systemd draait dat uitsluitend
  # wanneer `ExecStart` is geslaagd -- een mislukte sync laat het vorige moment
  # dus ongemoeid. Bedoeld voor losstaande bewaking (zie
  # home/module/staleness-monitor): die hoeft dan niets te parseren, want de
  # mtime *is* de state. Zonder dit bestond er geen bron van waarheid: systemd
  # kent alleen de uitkomst van de laatste run, en de journal doorzoeken voor
  # state is broos.
  stampFile = name: "${stateDir}/last-success-${name}";

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

    stampFiles = mkOption {
      type = types.attrsOf types.str;
      readOnly = true;
      default = mapAttrs (name: _: stampFile name) cfg.syncs;
      defaultText = literalExpression ''{ "<sync-naam>" = "~/.local/state/nextcloud-sync/last-success-<sync-naam>"; }'';
      description = ''
        Per sync-naam het pad naar het bestand waarvan de mtime het laatste
        geslaagde sync-moment is. Read-only; bedoeld om naar te verwijzen vanuit
        bewaking, zodat het pad niet op twee plekken hardgecodeerd staat:

        ```nix
        services.staleness-monitor.watch.nextcloud.stampFile =
          config.services.nextcloud-sync.stampFiles.docs;
        ```
      '';
    };

    quiet = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Geef `--silent` mee aan `nextcloudcmd`. Standaard **uit**: met die vlag
        logt nextcloudcmd niets, ook geen fouten, waardoor een kapotte sync
        onzichtbaar blijft. Zet alleen op `true` als de journal je te vol loopt
        en je de faalmelding elders al opvangt.
      '';
    };

    onFailure = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = literalExpression ''[ "notify-failure@%i.service" ]'';
      description = ''
        Units die systemd start zodra een sync faalt (`Unit.OnFailure`). Bedoeld
        voor een meldingskanaal, zodat een storing niet zeven dagen onopgemerkt
        blijft. `%i` is niet beschikbaar; gebruik een vaste unitnaam of een
        template met de sync-naam erin.
      '';
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
        # LET OP: hier stond `After`/`Wants = [ "network-online.target" ]`.
        # Die target bestaat NIET in de user-manager (`LoadState=not-found`), dus
        # de unit wachtte er in werkelijkheid nooit op -- gemeten 2026-09-17,
        # toen een sync vuurde op dezelfde seconde als de resume uit suspend,
        # met de wifi nog niet geassocieerd. Weggehaald omdat het een wachtgedrag
        # suggereerde dat er niet was; de bewaking vangt zo'n vroege mislukking op.
        Unit = {
          Description = "Nextcloud sync (${name})";
        } // optionalAttrs (cfg.onFailure != [ ]) {
          OnFailure = cfg.onFailure;
        };
        Service = {
          Type = "oneshot";
          # '-' => optioneel: ontbreken van het bestand faalt de unit niet
          # vóór ExecStartPre, zodat die een nette foutmelding kan geven.
          EnvironmentFile = "-${cfg.credentialsFile}";
          ExecStartPre = "${mkPreStart name sync}";
          ExecStart = mkExecStart name sync;
          # Draait alleen na een geslaagde ExecStart -> de mtime van dit bestand
          # is het laatste succesmoment. Zie de opmerking bij `stampFile`.
          ExecStartPost = "${pkgs.coreutils}/bin/touch ${escapeShellArg (stampFile name)}";
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
