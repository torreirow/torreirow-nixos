{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.magister-sync;
  nginxCfg = config.services.magister-sync.nginx;
  autheliaHelpers = import ../authelia-nginx.nix { inherit lib; };

  # Python omgeving met alle dependencies
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    playwright
    beautifulsoup4
    python-dateutil
    ics
  ]);

  # Magister server script uit de module directory
  magisterServerScript = ./magister_server.py;

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
      createHome = false;  # tmpfiles.rules maakt de directory aan met juiste permissies
      description = "Magister sync service user";
      extraGroups = [ "wheel" ];
    };

    users.groups.${cfg.group} = {};

    # Zorg dat de working directory en log directory de juiste permissies hebben
    # Group is nginx zodat nginx de bestanden kan lezen
    systemd.tmpfiles.rules = [
      "d ${cfg.workingDirectory} 0775 ${cfg.user} nginx -"
      "Z ${cfg.workingDirectory} 0775 ${cfg.user} nginx -"
      "L+ ${cfg.workingDirectory}/magister_server.py - - - - ${magisterServerScript}"
      "z ${cfg.workingDirectory}/*.ics 0664 ${cfg.user} nginx -"
      # Log directory voor magister
      "d /var/log/magister 0755 ${cfg.user} ${cfg.group} -"
    ];

    # Forceer tmpfiles rules bij elke rebuild om permissions te fixen
    system.activationScripts.magister-permissions = lib.stringAfter [ "users" "groups" ] ''
      ${pkgs.systemd}/bin/systemd-tmpfiles --create --prefix=${cfg.workingDirectory}
      ${pkgs.systemd}/bin/systemd-tmpfiles --create --prefix=/var/log/magister
    '';

    # Systemd service
    systemd.services.magister-sync = {
      description = "Magister Agenda Synchronisatie";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      # Maak chromium en which beschikbaar in PATH
      path = with pkgs; [ chromium which ];

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
        ReadWritePaths = [ cfg.workingDirectory "/var/log/magister" ];

        # Geef toegang tot network
        PrivateNetwork = false;
      };

      # Pre-start checks
      preStart = ''
        # Check of sessie bestand bestaat
        if [ ! -f "${cfg.workingDirectory}/magister_session.json" ]; then
          echo "ERROR: magister_session.json niet gevonden in ${cfg.workingDirectory}!"
          echo "Kopieer het sessie bestand naar ${cfg.workingDirectory}/ en herstart de service"
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

        # Locaties
        locations = {
          # Serve calendar .ics bestanden
          "~ ^/calendars/(.+\\.ics)$" = {
            root = cfg.workingDirectory;
            extraConfig = ''
              # iCalendar MIME type
              default_type text/calendar;
              add_header Content-Type "text/calendar; charset=utf-8";

              # Cache headers (5 minuten)
              add_header Cache-Control "public, max-age=300";

              # Security headers
              add_header X-Content-Type-Options "nosniff" always;
              add_header X-Frame-Options "SAMEORIGIN" always;
              add_header Referrer-Policy "strict-origin-when-cross-origin" always;

              # CORS headers (voor Google Calendar)
              add_header Access-Control-Allow-Origin "*";
              add_header Access-Control-Allow-Methods "GET, HEAD, OPTIONS";
              add_header Access-Control-Allow-Headers "Authorization";

              # Rewrite naar het juiste bestand
              rewrite ^/calendars/(.+)$ /$1 break;

              # Handle OPTIONS requests
              if ($request_method = 'OPTIONS') {
                add_header X-Content-Type-Options "nosniff" always;
                add_header X-Frame-Options "SAMEORIGIN" always;
                add_header Referrer-Policy "strict-origin-when-cross-origin" always;
                add_header Access-Control-Allow-Origin "*" always;
                add_header Access-Control-Allow-Methods "GET, HEAD, OPTIONS" always;
                add_header Access-Control-Allow-Headers "Authorization" always;
                add_header Access-Control-Max-Age 1728000 always;
                add_header Cache-Control "public, max-age=300" always;
                add_header Content-Type "text/plain; charset=UTF-8" always;
                add_header Content-Length 0 always;
                return 204;
              }
            '';
          };
          # Authelia verify endpoint
          "/authelia" = autheliaHelpers.autheliaVerifyLocation;

          # Root locatie met overzicht (beschermd door Authelia)
          "/" = {
            root = cfg.workingDirectory;
            extraConfig = ''
              # Authelia authentication
              ${autheliaHelpers.autheliaAuthConfig}

              # Serve index.html als die bestaat
              try_files /index.html =404;
            '';
          };
        };
      };
    };

    # Nginx hoeft niet aan extra groepen toegevoegd te worden
    # De bestanden zijn owned door magister:nginx

    # Log rotation configuratie
    services.logrotate.settings.magister = {
      files = "/var/log/magister/*.log";
      frequency = "daily";
      rotate = 3;  # Bewaar 3 dagen
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
      su = "${cfg.user} ${cfg.group}";
      postrotate = ''
        # Optional: Signal de service om nieuwe log te starten
        # systemctl kill -s USR1 magister-sync.service 2>/dev/null || true
      '';
    };
  };
}
