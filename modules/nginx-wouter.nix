{ config, pkgs, ... }:

{
  services.nginx = {
    virtualHosts."wouter.toorren.net" = {
      root = "/var/www/wouter";

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

  # Create wouter website directory
  systemd.tmpfiles.rules = [
    "d /var/www/wouter 0755 root root -"
  ];
}
