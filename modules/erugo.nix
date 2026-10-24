{ config, pkgs, ... }:

{
  virtualisation.oci-containers.containers.erugo = {
    # https://github.com/torreirow/erugo-php: upstream v0.2.15 op Alpine 3.22 met PHP 8.3.36
    # (PHP2Shell). Upstream (wardy784/erugo:latest) zit vast op Alpine 3.19 / PHP 8.3.14.
    # Terug naar upstream zodra die een image met PHP >= 8.3.36 publiceert.
    image = "ghcr.io/torreirow/erugo-php@sha256:14bb3e8f6636e3107343da5f62ee05d3a8221db0178646a4399161f4130ea654"; # PHP 8.3.36
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

