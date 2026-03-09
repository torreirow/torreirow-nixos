{ config, pkgs, ... }:

{
  virtualisation.oci-containers.containers.erugo = {
    image = "wardy784/erugo:latest";
    autoStart = true;

    ports = [
      "127.0.0.1:8083:80"
    ];
    volumes = [
      "/data/external/erugo/config:/var/www/html/storage"
    ];
  };

  services.nginx = {
    virtualHosts."filesender.toorren.net" = {
      forceSSL = true;
      useACMEHost = "toorren.net";

      locations."/" = {
        proxyPass = "http://127.0.0.1:8083";
        proxyWebsockets = true;
        extraConfig = ''
          client_max_body_size 50G;
          client_body_timeout 3600s;
          proxy_request_buffering off;
        '';
      };
    };

  };
}

