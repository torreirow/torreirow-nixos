{ config, lib, pkgs, ... }:

# Magister Sync Service Module
#
# Auth: OAuth refresh-token flow (mobiele-app-client M6LOAPP) via token.json.
# Het access-token wordt stil ververst; het refresh-token roteert en wordt
# teruggeschreven naar token.json. Geen browser/cookie-sessie meer.
#
# Error Handling & Email Notificaties:
# - Bij token problemen (token.json ontbreekt of refresh-token invalid_grant):
#   * Python script verstuurt email naar: wvdtoorren@gmail.com (hardcoded in magister_server.py)
#   * Service stopt met exit code 1 en wordt NIET automatisch herstart
#   * Handmatige interventie vereist: verify_pkce.py op de laptop (passkey), nieuw
#     refresh_token in token.json zetten
#
# - Bij andere fouten (netwerk, tijdelijke problemen):
#   * Service herstart automatisch na 60 seconden (max 5 pogingen binnen 10 minuten)
#
# - Bij succesvolle start:
#   * Nginx wordt gereload om nieuwe .ics bestanden beschikbaar te maken

with lib;

let
  cfg = config.services.magister-sync;
  nginxCfg = config.services.magister-sync.nginx;
  autheliaHelpers = import ../authelia-nginx.nix { inherit lib; };

  # Python omgeving. Sinds de refresh-token-ombouw geen browser meer nodig:
  # HTTP via stdlib urllib, alleen bs4 (inhoud-HTML) + dateutil (datums) resten.
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    beautifulsoup4
    python-dateutil
  ]);

  # Magister server script uit de module directory
  magisterServerScript = ./magister_server.py;

  # Wrapper script - laat Python script alle checks en emails afhandelen
  magisterScript = pkgs.writeShellScript "magister-sync" ''
    set -e

    cd ${cfg.workingDirectory}

    # Start het script - bij een ongeldig refresh-token stopt het met exit code 1
    # en verstuurt het een email (RestartPreventExitStatus=1 -> geen retry)
    ${pythonEnv}/bin/python ${cfg.workingDirectory}/magister_server.py
  '';

in {
  options.services.magister-sync = {
    enable = mkEnableOption "Magister agenda synchronisatie service";

    workingDirectory = mkOption {
      type = types.path;
      default = "/var/lib/magister";
      description = ''
        Directory waar magister_server.py en token.json staan.
        Zorg dat token.json (met een geldig refresh_token) in deze directory staat
        voordat je de service start. Seed via verify_pkce.py op de laptop.
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
      extraGroups = [ "wheel" "postdrop" ];  # postdrop nodig voor email verzending
    };

    users.groups.${cfg.group} = {};

    # Voeg nginx toe aan magister group zodat nginx de .ics bestanden kan lezen
    users.users.nginx.extraGroups = [ cfg.group ];

    # Zorg dat de working directory en log directory de juiste permissies hebben
    # Alleen .ics bestanden hebben nginx group voor webserver toegang
    systemd.tmpfiles.rules = [
      "d ${cfg.workingDirectory} 0750 ${cfg.user} ${cfg.group} -"
      "z ${cfg.workingDirectory} 0750 ${cfg.user} ${cfg.group} -"  # Force correct permissions
      "L+ ${cfg.workingDirectory}/magister_server.py - - - - ${magisterServerScript}"
      "z ${cfg.workingDirectory}/*.ics 0664 ${cfg.user} nginx -"
      "z ${cfg.workingDirectory}/index.html 0664 ${cfg.user} nginx -"
      # Log directory voor magister
      "d /var/log/magister 0750 ${cfg.user} ${cfg.group} -"
    ];

    # Systemd service
    systemd.services.magister-sync = {
      description = "Magister Agenda Synchronisatie";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      # Sendmail (postfix) beschikbaar in PATH voor e-mailnotificaties
      path = with pkgs; [ postfix ];

      # Service configuratie
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.workingDirectory;

        # Start het script
        ExecStart = "${magisterScript}";

        # Restart policy: voorkom herhaaldelijke failures bij sessie problemen
        # - Bij exit code 1 (sessie ongeldig): GEEN restart, service stopt definitief
        # - Bij andere failures: herstart na 60 seconden (bijv. tijdelijke netwerkproblemen)
        # - Python script verstuurt email naar ${ERROR_EMAIL} bij sessie problemen
        Restart = "on-failure";
        RestartSec = "60s";
        RestartPreventExitStatus = "1";  # Exit code 1 = sessie ongeldig, geen retry

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [
          cfg.workingDirectory
          "/var/log/magister"
          "/var/lib/postfix/queue"  # Nodig voor email verzending via postfix
          "/var/lib/prometheus-node-exporter-textfiles"  # Nodig voor heartbeat metric
        ];

        # Geef toegang tot network
        PrivateNetwork = false;
      };

      # Pre-start checks (alleen warning, laat Python script de email verzorgen)
      preStart = ''
        # Check of token-bestand bestaat (maar fail niet, laat Python script errors afhandelen)
        if [ ! -f "${cfg.workingDirectory}/token.json" ]; then
          echo "WARNING: token.json niet gevonden in ${cfg.workingDirectory}!"
          echo "Seed het met een refresh_token (verify_pkce.py op de laptop)."
          echo "Het Python script zal een error email verzenden en stoppen."
        else
          echo "Pre-flight checks geslaagd"
        fi
      '';

      # Post-start: reload nginx om nieuwe .ics bestanden beschikbaar te maken
      postStart = mkIf nginxCfg.enable ''
        echo "Magister sync gestart - nginx herladen om nieuwe calendars beschikbaar te maken..."
        ${pkgs.systemd}/bin/systemctl reload nginx.service || true
      '';
    };

    # Installeer benodigde system packages
    environment.systemPackages = [
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
