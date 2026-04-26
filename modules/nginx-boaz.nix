{ config, pkgs, ... }:

{
  services.nginx = {
    virtualHosts."boaz.toorren.net" = {
      root = "/var/www/boaz";

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

  # Create boaz website directory
  systemd.tmpfiles.rules = [
    "d /var/www/boaz 0755 root root -"
  ];
}
