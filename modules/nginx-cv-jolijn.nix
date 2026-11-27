{ config, pkgs, ... }:

# CV-site van Jolijn, achter dezelfde Anubis-browsercontrole als de
# Wouter-CV. De publieke vhost proxyt naar Anubis; de statische site staat
# alleen op een lokale backend-vhost.
let
  backendPort = 8183;
  anubisPort = 9302;
in
{
  services.anubis.instances."cv-jolijn" = {
    settings = {
      BIND = "127.0.0.1:${toString anubisPort}";
      BIND_NETWORK = "tcp";
      TARGET = "http://127.0.0.1:${toString backendPort}";
      PUBLIC_URL = "https://cv-jolijn.toorren.net";
      REDIRECT_DOMAINS = "cv-jolijn.toorren.net";
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

  systemd.services."anubis-cv-jolijn".serviceConfig = {
    Restart = "on-failure";
    RestartSec = 2;
  };

  services.nginx = {
    virtualHosts."cv-jolijn-backend" = {
      listen = [
        {
          addr = "127.0.0.1";
          port = backendPort;
        }
      ];
      http2 = false;
      serverName = "cv-jolijn-backend";
      root = "/var/www/cv-jolijn";

      locations."/" = {
        tryFiles = "$uri $uri/ =404";
      };

      extraConfig = ''
        index index.html;
      '';
    };

    virtualHosts."cv-jolijn.toorren.net" = {
      forceSSL = true;
      useACMEHost = "toorren.net";

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString anubisPort}";
      };
    };
  };
}
