{ config, pkgs, ... }:

# Boaz' site, achter dezelfde Anubis-browsercontrole als de CV-sites.
let
  backendPort = 8184;
  anubisPort = 9303;
in
{
  services.anubis.instances."boaz" = {
    settings = {
      BIND = "127.0.0.1:${toString anubisPort}";
      BIND_NETWORK = "tcp";
      TARGET = "http://127.0.0.1:${toString backendPort}";
      PUBLIC_URL = "https://boaz.toorren.net";
      REDIRECT_DOMAINS = "boaz.toorren.net";
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

  systemd.services."anubis-boaz".serviceConfig = {
    Restart = "on-failure";
    RestartSec = 2;
  };

  services.nginx = {
    virtualHosts."boaz-backend" = {
      listen = [
        {
          addr = "127.0.0.1";
          port = backendPort;
        }
      ];
      http2 = false;
      serverName = "boaz-backend";
      root = "/var/www/boaz";

      locations."/" = {
        tryFiles = "$uri $uri/ =404";
      };

      extraConfig = ''
        index index.html;
      '';
    };

    virtualHosts."boaz.toorren.net" = {
      forceSSL = true;
      useACMEHost = "toorren.net";

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString anubisPort}";
      };
    };
  };

  # Create boaz website directory
  systemd.tmpfiles.rules = [
    "d /var/www/boaz 0755 root root -"
  ];
}
