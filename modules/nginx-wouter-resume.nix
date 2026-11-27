{ config, lib, pkgs, ... }:

# CV-site van Wouter van der Toorren.
#
# Bezoekersflow:
#   browser -> nginx (TLS) -> Anubis (proof-of-work) -> nginx backend -> site
#
# Anubis daagt elke request uit. Na een geldige challenge krijgt de bezoeker een
# ondertekende cookie; niet-browsers (curl, scrapers, AI-crawlers) komen zonder
# JavaScript niet door. Open Graph-passthrough staat aan zodat linkpreviews
# titel en beschrijving kunnen lezen, maar niet de pagina-inhoud.
#
# De PDF's blijven dubbel beschermd: Anubis op de site en de Cap-broker op
# /download. Directe /uploads/*.pdf-requests geven 404.
#
# Rollback: verwijder de Anubis-proxy uit de publieke vhost en zet de statische
# locaties terug; de backend-vhost kan blijven staan.

let
  # Kleine broker die Cap-tokens verifieert voordat de PDF wordt uitgeleverd.
  # De PDF's staan wel in de webroot (release.sh deployt ze daar), maar nginx
  # blokkeert directe toegang; alleen deze service leest ze van schijf.
  brokerPort = 8787;

  # Lokale backend achter Anubis. Niet publiek bereikbaar.
  backendPort = 8182;

  anubisPort = 9301;
in
{
  # Cap key-secret van site key a9194a3d45 (agenix; nooit plaintext in de repo).
  age.secrets.cap-cv-secret = {
    file = ../secrets/cap-cv-secret.age;
    path = "/run/secrets/cap-cv-secret";
    owner = "cv-download";
    group = "cv-download";
    mode = "0400";
  };

  users.groups.cv-download = { };
  users.users.cv-download = {
    isSystemUser = true;
    group = "cv-download";
    # /run/keys (waar agenix de secrets neerzet) is root:keys 0750.
    extraGroups = [ "keys" ];
  };

  systemd.services.cv-download = {
    description = "CV-downloadbroker (Cap siteverify)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${./cv-download-broker.py}";
      User = "cv-download";
      Group = "cv-download";
      Restart = "on-failure";
      RestartSec = 2;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadOnlyPaths = [ "/var/www/cv-wouter/uploads" ];
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
    };
  };

  # Anubis: proof-of-work voor elke request. De catch-all-regel vervangt de
  # standaardregels, omdat die gewone browsers juist zouden allowen.
  services.anubis.instances.cv = {
    settings = {
      BIND = "127.0.0.1:${toString anubisPort}";
      BIND_NETWORK = "tcp";
      TARGET = "http://127.0.0.1:${toString backendPort}";
      PUBLIC_URL = "https://wouter-resume.toorren.net";
      REDIRECT_DOMAINS = "wouter-resume.toorren.net";
      DIFFICULTY = 4;
      OG_PASSTHROUGH = true;
    };
    policy = {
      useDefaultBotRules = false;
      extraBots = [
        {
          name = "everyone";
          user_agent_regex = ".*";
          action = "CHALLENGE";
        }
      ];
    };
  };

  systemd.services."anubis-cv".serviceConfig = {
    Restart = "on-failure";
    RestartSec = 2;
  };

  services.nginx = {
    # Lokale backend: de enige plek waar de statische site en de broker
    # bereikbaar zijn. Gebonden aan localhost, dus niet van buitenaf.
    virtualHosts."cv-wouter-backend" = {
      listen = [
        {
          addr = "127.0.0.1";
          port = backendPort;
        }
      ];
      http2 = false;
      serverName = "cv-wouter-backend";

      root = "/var/www/cv-wouter";

      locations."/" = {
        tryFiles = "$uri $uri/ =404";
      };

      # Downloads alleen via de broker (Cap-token verplicht).
      locations."/download" = {
        proxyPass = "http://127.0.0.1:${toString brokerPort}";
        extraConfig = ''
          client_max_body_size 8k;
          add_header Cache-Control "no-store";
        '';
      };

      # Geen directe toegang tot de PDF's.
      locations."~* ^/uploads/.*\\.pdf$" = {
        return = "404";
      };

      locations."= /healthz" = {
        return = "200";
        extraConfig = "access_log off;";
      };

      extraConfig = ''
        index index.html;
      '';
    };

    # Canonieke host: alles via Anubis.
    virtualHosts."wouter-resume.toorren.net" = {
      forceSSL = true;
      useACMEHost = "toorren.net";

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString anubisPort}";
        # Host/X-Real-IP/X-Forwarded-* komen uit recommendedProxySettings.
        extraConfig = "";
      };

      # Health check alleen vanaf de server zelf. De allow/deny moet in de
      # proxy-locatie staan; `return` zou de access-fase overslaan.
      locations."= /healthz" = {
        proxyPass = "http://127.0.0.1:${toString backendPort}/healthz";
        extraConfig = ''
          allow 127.0.0.1;
          allow ::1;
          deny all;
          access_log off;
        '';
      };

      # ACME draait via DNS-01; er is geen HTTP-challengepad nodig. Wel
      # expliciet afvangen zodat het niet per ongeluk via Anubis loopt.
      locations."/.well-known/acme-challenge/" = {
        return = "404";
      };
    };

    # Oude naam: permanent doorverwijzen, pad en query blijven behouden.
    virtualHosts."cv-wouter.toorren.net" = {
      forceSSL = true;
      useACMEHost = "toorren.net";

      locations."/" = {
        return = "301 https://wouter-resume.toorren.net$request_uri";
      };
    };
  };
}
