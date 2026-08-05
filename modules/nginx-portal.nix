{ config, pkgs, ... }:

{
  services.phpfpm.pools.portal = {
    user = "nginx";
    group = "nginx";

    phpPackage = pkgs.php83;

    settings = {
      "listen.owner" = "nginx";
      "listen.group" = "nginx";
      "pm" = "ondemand";
      "pm.max_children" = 5;
      "pm.process_idle_timeout" = "10s";
    };
  };

  services.nginx.virtualHosts."toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";
    root = "/var/www/toorren.net";

    locations."/" = {
      tryFiles = "$uri $uri/ =404";
    };

    locations."~ \\.php$" = {
      extraConfig = ''
        fastcgi_pass unix:${config.services.phpfpm.pools.portal.socket};
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include ${pkgs.nginx}/conf/fastcgi_params;
      '';
    };

    locations."/errors/" = {
      root = "/var/www";
      extraConfig = "internal;";
    };

    locations."~* ^/errors/.*\\.png$" = {
      root = "/var/www";
    };

    extraConfig = ''
      index index.php index.html;
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
