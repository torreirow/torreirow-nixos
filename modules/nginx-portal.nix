{ config, ... }:

{
  services.nginx.virtualHosts."toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";
    root = "/var/www/toorren.net";

    locations."/" = {
      tryFiles = "$uri $uri/ =404";
    };

    locations."/week/" = {
      alias = "/var/www/toorren.net/week/";
      tryFiles = "$uri $uri/ =404";
      extraConfig = "index index.html;";
    };

    locations."= /week" = {
      return = "301 /week/";
    };

    extraConfig = ''
      index index.html;
    '';
  };

  services.nginx.virtualHosts."www.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";
    globalRedirect = "toorren.net";
  };

  systemd.tmpfiles.rules = [
    "d /var/www/toorren.net 0755 nginx nginx -"
  ];
}
