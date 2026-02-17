{ config, pkgs, ... }:

{
  services.nginx = {

    virtualHosts."cv-jolijn.toorren.net" = {
      root = "/var/www/cv-jolijn";

      forceSSL = true;
      useACMEHost = "toorren.net";

      locations."/" = {
        tryFiles = "$uri $uri/ =404";
      };
      extraConfig = ''
        index index.html;
      '';

    };
  };

}

