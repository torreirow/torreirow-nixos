{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.magister-sync;
  nginxCfg = config.services.magister-sync.nginx;

  # Python omgeving met alle dependencies
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    playwright
    beautifulsoup4
    python-dateutil
    ics
  ]);

  # Wrapper script dat checkt op sessie validiteit
  magisterScript = pkgs.writeShellScript "magister-sync" ''
    set -e

    cd ${cfg.workingDirectory}

    # Check of sessie bestand bestaat
    if [ ! -f "${cfg.workingDirectory}/magister_session.json" ]; then
      echo "ERROR: magister_session.json niet gevonden in ${cfg.workingDirectory}"
      echo "Kopieer het sessie bestand en herstart de service"
      exit 1
    fi

    # Voer het script uit
    export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
    export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

    # Start het script - als de sessie ongeldig is, stopt het script met exit code != 0
    ${pythonEnv}/bin/python ${cfg.workingDirectory}/magister_server.py
  '';

in {
  options.services.magister-sync = {
    enable = mkEnableOption "Magister agenda synchronisatie service";

    workingDirectory = mkOption {
      type = types.path;
      default = "/var/lib/magister";
      description = ''
        Directory waar magister_server.py en magister_session.json staan.
        Zorg dat magister_session.json in deze directory staat voordat je de service start.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "magister";
      description = "User onder wie de service draait";
    };

    group = mkOption {
      type = types.str;
      default = "magister";
      description = "Group onder wie de service draait";
    };

    nginx = {
      enable = mkEnableOption "Nginx configuratie voor iCal feeds";

      domain = mkOption {
        type = types.str;
        default = "agenda.toorren.net";
        description = "Domein voor de iCal feeds";
      };

      acmeHost = mkOption {
        type = types.str;
        default = "toorren.net";
        description = "ACME host voor SSL certificaat";
      };

      children = mkOption {
        type = types.listOf (types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "Naam van het kind (wordt gebruikt in URL en bestandsnaam)";
              example = "noraly";
            };
            path = mkOption {
              type = types.str;
              description = "URL pad voor deze agenda";
              example = "/noraly";
            };
          };
        });
        default = [
          { name = "noraly"; path = "/noraly"; }
          { name = "boaz"; path = "/boaz"; }
        ];
        description = "Lijst van kinderen met hun agenda paden";
      };
    };
  };

  config = mkIf cfg.enable {
    # Maak user en group aan
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.workingDirectory;
      createHome = true;
      description = "Magister sync service user";
    };

    users.groups.${cfg.group} = {};

    # Systemd service
    systemd.services.magister-sync = {
      description = "Magister Agenda Synchronisatie";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      # Service configuratie
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.workingDirectory;

        # Start het script
        ExecStart = "${magisterScript}";

        # Restart policy: stop bij sessie errors, anders herstart
        Restart = "on-failure";
        RestartSec = "60s";

        # Stop service als script zelf stopt (bijv. bij ongeldige sessie)
        # En herstart NIET als exit code 1 is (sessie ongeldig)
        RestartPreventExitStatus = "1";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.workingDirectory ];

        # Geef toegang tot network
        PrivateNetwork = false;
      };

      # Pre-start checks
      preStart = ''
        # Check of sessie bestand bestaat
        if [ ! -f "${cfg.workingDirectory}/magister_session.json" ]; then
          echo "WAARSCHUWING: magister_session.json niet gevonden!"
          echo "Plaats het bestand in ${cfg.workingDirectory}/ en herstart de service"
          exit 1
        fi

        # Check of magister_server.py bestaat
        if [ ! -f "${cfg.workingDirectory}/magister_server.py" ]; then
          echo "ERROR: magister_server.py niet gevonden in ${cfg.workingDirectory}!"
          exit 1
        fi

        echo "Pre-flight checks geslaagd"
      '';
    };

    # Installeer benodigde system packages
    environment.systemPackages = with pkgs; [
      chromium
      pythonEnv
    ];

    # Nginx configuratie voor iCal feeds
    services.nginx = mkIf nginxCfg.enable {
      enable = true;

      virtualHosts.${nginxCfg.domain} = {
        forceSSL = true;
        useACMEHost = nginxCfg.acmeHost;

        # Extra headers voor iCal compatibiliteit
        extraConfig = ''
          # Security headers
          add_header X-Content-Type-Options "nosniff" always;
          add_header X-Frame-Options "SAMEORIGIN" always;
          add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        '';

        # Locaties voor elk kind
        locations = listToAttrs (map (child: {
          name = child.path;
          value = {
            alias = "${cfg.workingDirectory}/magister_${child.name}.ics";
            extraConfig = ''
              # iCalendar MIME type
              default_type text/calendar;
              add_header Content-Type "text/calendar; charset=utf-8";

              # Cache headers (5 minuten)
              add_header Cache-Control "public, max-age=300";

              # CORS headers (voor Google Calendar)
              add_header Access-Control-Allow-Origin "*";
              add_header Access-Control-Allow-Methods "GET, HEAD, OPTIONS";
              add_header Access-Control-Allow-Headers "Authorization";

              # Handle OPTIONS requests
              if ($request_method = 'OPTIONS') {
                add_header Access-Control-Allow-Origin "*";
                add_header Access-Control-Allow-Methods "GET, HEAD, OPTIONS";
                add_header Access-Control-Max-Age 1728000;
                add_header Content-Type "text/plain charset=UTF-8";
                add_header Content-Length 0;
                return 204;
              }
            '';
          };
        }) nginxCfg.children);

        # Root locatie met overzicht
        locations."/".extraConfig = ''
          default_type text/html;
          return 200 '<!DOCTYPE html>
<html>
<head>
  <title>Magister Agenda Feeds</title>
  <style>
    body { font-family: sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
    h1 { color: #333; }
    .feed { background: #f5f5f5; padding: 15px; margin: 10px 0; border-radius: 5px; }
    .url { background: #fff; padding: 10px; border: 1px solid #ddd; border-radius: 3px;
           font-family: monospace; word-break: break-all; }
    code { background: #e0e0e0; padding: 2px 5px; border-radius: 3px; }
  </style>
</head>
<body>
  <h1>Magister Agenda Feeds</h1>
  <p>Beschikbare iCalendar feeds:</p>
  ${concatMapStringsSep "\n" (child: ''
    <div class="feed">
      <h2>${child.name}</h2>
      <div class="url">https://${nginxCfg.domain}${child.path}</div>
      <p>Gebruik deze URL in Google Calendar via <code>Toevoegen</code> → <code>Via URL</code></p>
    </div>
  '') nginxCfg.children}
  <hr>
  <p><small>Updates elke 28 minuten</small></p>
</body>
</html>';
        '';
      };
    };

    # Zorg dat nginx de iCal bestanden kan lezen
    users.users.nginx.extraGroups = mkIf nginxCfg.enable [ cfg.group ];
  };
}
