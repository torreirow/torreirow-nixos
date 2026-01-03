{ config, pkgs, ... }:

{
  ### MariaDB ###
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
  };

  ### PHP-FPM ###
  services.phpfpm.pools.castopod = {
    user = "nginx";
    group = "nginx";

    phpPackage = pkgs.php83;

    settings = {
      "listen.owner" = "nginx";
      "listen.group" = "nginx";

      "pm" = "dynamic";
      "pm.max_children" = 32;
      "pm.start_servers" = 4;
      "pm.min_spare_servers" = 2;
      "pm.max_spare_servers" = 8;

      "php_admin_value[memory_limit]" = "512M";
      "php_admin_value[upload_max_filesize]" = "64M";
      "php_admin_value[post_max_size]" = "64M";
      "php_admin_value[max_execution_time]" = "300";
    };
  };

  ### NGINX ###
  services.nginx.enable = true;
  services.nginx.virtualHosts."podcast.toorren.net" = {
    serverAliases = ["castopod.toorren.net"];
    enableACME = true;
    forceSSL = true;
		extraConfig = ''
						index index.php;
						keepalive_timeout 5m;
						send_timeout 5m;
						client_body_timeout 5m;
						client_header_timeout 5m;
						proxy_connect_timeout 5m;
						proxy_read_timeout 5m;
						proxy_send_timeout 5m;
						fastcgi_connect_timeout 5m;
						fastcgi_read_timeout 5m;
						fastcgi_send_timeout 5m;
						memcached_connect_timeout 5m;
						memcached_read_timeout 5m;
            memcached_send_timeout 5m;
            client_max_body_size 1G;
		'';
    root = "/data/external/tmp/castopod/public";

    locations."/" = {
      tryFiles = "$uri $uri/ /index.php?$args";
    };

    locations."~\\.php$" = {
      extraConfig = ''
        include ${pkgs.nginx}/conf/fastcgi.conf;
        fastcgi_pass unix:${config.services.phpfpm.pools.castopod.socket};
      '';
    };

    locations."~*\\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf)$" = {
      extraConfig = ''
        expires 30d;
        access_log off;
      '';
    };
  };
}

