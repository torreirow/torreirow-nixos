{ config, pkgs, lib, ... }:

let
  invoiceplaneRoot = "/data/external/invoiceplane";
in
{
  # MySQL database for InvoicePlane
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    ensureDatabases = [ "invoiceplane" ];
    ensureUsers = [
      {
        name = "invoiceplane";
        ensurePermissions = {
          "invoiceplane.*" = "ALL PRIVILEGES";
        };
      }
    ];
  };

  # PHP-FPM pool for InvoicePlane
  services.phpfpm.pools.invoiceplane = {
    user = "nginx";
    group = "nginx";

    phpPackage = pkgs.php83.buildEnv {
      extensions = { enabled, all }: enabled ++ (with all; [
        mysqli
        pdo
        pdo_mysql
        mbstring
        gd
        curl
        zip
        fileinfo
        openssl
        bcmath
      ]);
      extraConfig = ''
        memory_limit = 256M
        upload_max_filesize = 20M
        post_max_size = 20M
        max_execution_time = 300
        date.timezone = "Europe/Amsterdam"
      '';
    };

    settings = {
      "listen.owner" = "nginx";
      "listen.group" = "nginx";

      "pm" = "dynamic";
      "pm.max_children" = 32;
      "pm.start_servers" = 4;
      "pm.min_spare_servers" = 2;
      "pm.max_spare_servers" = 8;

      "php_admin_value[memory_limit]" = "256M";
      "php_admin_value[upload_max_filesize]" = "20M";
      "php_admin_value[post_max_size]" = "20M";
      "php_admin_value[max_execution_time]" = "300";
    };
  };

  # Create InvoicePlane data directories
  systemd.tmpfiles.rules = [
    "d ${invoiceplaneRoot} 0755 nginx nginx -"
    "d ${invoiceplaneRoot}/uploads 0755 nginx nginx -"
    "d ${invoiceplaneRoot}/logs 0755 nginx nginx -"
  ];

  # Nginx configuration for InvoicePlane
  services.nginx = {
    enable = true;

    virtualHosts."invoices.toorren.net" = {
      useACMEHost = "toorren.net";
      forceSSL = true;

      root = invoiceplaneRoot;

      extraConfig = ''
        index index.php;
        client_max_body_size 20M;
      '';

      locations."/" = {
        tryFiles = "$uri $uri/ /index.php?$query_string";

        extraConfig = ''
          # Authelia forward authentication
          auth_request /authelia;
          auth_request_set $user $upstream_http_remote_user;
          auth_request_set $groups $upstream_http_remote_groups;
          auth_request_set $name $upstream_http_remote_name;
          auth_request_set $email $upstream_http_remote_email;

          # Redirect to Authelia portal on auth failure
          error_page 401 = @authelia_portal;

          # Pass authentication headers to backend
          proxy_set_header Remote-User $user;
          proxy_set_header Remote-Groups $groups;
          proxy_set_header Remote-Name $name;
          proxy_set_header Remote-Email $email;
        '';
      };

      locations."~ \\.php$" = {
        extraConfig = ''
          include ${pkgs.nginx}/conf/fastcgi.conf;
          fastcgi_pass unix:${config.services.phpfpm.pools.invoiceplane.socket};
          fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
          fastcgi_intercept_errors on;
        '';
      };

      # Deny access to sensitive files
      locations."~ /\\." = {
        extraConfig = ''
          deny all;
          access_log off;
          log_not_found off;
        '';
      };

      locations."~ /(ipconfig\\.php|database\\.php)" = {
        extraConfig = ''
          deny all;
        '';
      };

      # Static files caching
      locations."~* \\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$" = {
        extraConfig = ''
          expires 30d;
          access_log off;
          log_not_found off;
        '';
      };

      # Authelia redirect named location
      locations."@authelia_portal" = {
        extraConfig = ''
          return 302 https://auth.toorren.net/?rd=$scheme://$http_host$request_uri;
        '';
      };

      # Authelia authentication endpoint
      locations."/authelia" = {
        proxyPass = "http://127.0.0.1:9091/api/verify";
        extraConfig = ''
          internal;
          proxy_set_header Host $host;
          proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
          proxy_set_header X-Forwarded-Method $request_method;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Host $http_host;
          proxy_set_header X-Forwarded-Uri $request_uri;
          proxy_set_header X-Forwarded-For $remote_addr;
          proxy_set_header Content-Length "";
          proxy_pass_request_body off;
        '';
      };
    };
  };
}
