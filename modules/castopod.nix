{ config, pkgs, lib, agenix, ... }:

let
  domain = "podcast.toorren.net";
  dataDir = "/data/external/castopod";
in
{
  #### Secrets ######################################################
  age.secrets = {
    castopod-db-password.file = ../secrets/castopod-db-password.age;
    castopod-analytics-salt.file = ../secrets/castopod-analytics-salt.age;
  };

  #### Docker & Containers ##########################################
  virtualisation.docker.enable = true;
  
  # Data directories
  systemd.tmpfiles.rules = [
    "d /data/external/castopod 0755 root root - -"
    "d ${dataDir}/media 0775 1000:1000 - -"
    "d ${dataDir}/db    0775 999:999  - -"
    "d ${dataDir}/cache 0775 999:999  - -"
  ];

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      castopod = {
        image = "castopod/castopod:latest";
        ports = [ "8000:8000" ];
        volumes = [
          "${dataDir}/media:/var/www/castopod/public/media"
        ];
        environment = {
          MYSQL_DATABASE = "castopod";
          MYSQL_USER = "castopod";
          MYSQL_PASSWORD_FILE = config.age.secrets.castopod-db-password.path;
          CP_BASEURL = "https://${domain}";
          CP_ANALYTICS_SALT_FILE = config.age.secrets.castopod-analytics-salt.path;
          CP_CACHE_HANDLER = "redis";
          CP_REDIS_HOST = "castopod-mariadb";
          CP_REDIS_PASSWORD = "changeme";
        };
        autoStart = true;
      };
      
      castopod-mariadb = {
        image = "mariadb:11.2";
        volumes = [ "${dataDir}/db:/var/lib/mysql" ];
        environment = {
          MYSQL_ROOT_PASSWORD_FILE = config.age.secrets.castopod-db-password.path;
          MYSQL_DATABASE = "castopod";
          MYSQL_USER = "castopod";
          MYSQL_PASSWORD_FILE = config.age.secrets.castopod-db-password.path;
        };
        autoStart = true;
      };
      
      castopod-redis = {
        image = "redis:7.2-alpine";
        volumes = [ "${dataDir}/cache:/data" ];
        extraOptions = [ "--requirepass" "changeme" ];
        autoStart = true;
      };
    };
  };

  #### Network & Firewall ###########################################
#  networking.firewall.allowedTCPPorts = [ 8000 ];

  #### Nginx Reverse Proxy ##########################################
  services.nginx = {
    enable = true;
    virtualHosts."${domain}" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:8086";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          client_max_body_size 100M;
        '';
      };
    };
  };
}

