{ config, pkgs, ... }:

{
  virtualisation.oci-containers.containers.erugo = {
    image = "wardy784/erugo:latest";
    autoStart = true;

    ports = [
      "127.0.0.1:8083:80"
    ];
    volumes = [
      "/var/lib/erugo/config:/var/www/html/storage"
    ];
  };

  services.nginx = {
    virtualHosts."filesender.toorren.net" = {
      enableACME = true;
      forceSSL = true;

      locations."/" = {
        proxyPass = "http://127.0.0.1:8083";
        proxyWebsockets = true;
      };
    };

  };
}

