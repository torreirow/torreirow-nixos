{ config, lib, pkgs, ... }:

{
  # Fail2ban configuration for NixOS 25.11

  services.fail2ban = {
    enable = true;

    # Whitelist trusted IPs
    ignoreIP = [
      "127.0.0.1/8"
      "::1"
      "192.168.2.0/24"  # Local network
    ];

    # Ban action (default is iptables-multiport)
    banaction = "iptables-multiport";

    # Ban action for IPv6
    banaction-allports = "iptables-allports";

    # Jail configurations
    jails = {
      # SSH protection
      sshd = {
        settings = {
          enabled = true;
          port = "ssh";
          filter = "sshd";
          maxretry = 5;
          findtime = "10m";
          bantime = "10m";
        };
      };
    } // lib.optionalAttrs config.services.nginx.enable {
      # Nginx protection (only if nginx is enabled)
      nginx-http-auth = {
        settings = {
          enabled = true;
          filter = "nginx-http-auth";
          port = "http,https";
          logpath = "/var/log/nginx/error.log";
          maxretry = 5;
          findtime = "10m";
          bantime = "10m";
        };
      };

      nginx-limit-req = {
        settings = {
          enabled = true;
          filter = "nginx-limit-req";
          port = "http,https";
          logpath = "/var/log/nginx/error.log";
          maxretry = 10;
          findtime = "10m";
          bantime = "10m";
        };
      };

      # Vulnerability-scanners (WordPress/Joomla/.env/.git/phpMyAdmin). Leest het access-
      # log als bestand (backend auto), want nginx schrijft dat niet naar de journal.
      # Alleen requests zonder ingelogde gebruiker ("- - [") tellen, en Nextcloud-paden
      # (/ocs, /remote.php, /index.php/...) zijn uitgezonderd: de Nextcloud-client krijgt
      # legitiem 404's op /ocs/v2.php/apps/terms_of_service. Getoetst op ~5 maanden log
      # (2026-05..10): geen eigen IP's of app-clients geraakt.
      nginx-scanner = {
        filter.Definition = {
          failregex = ''
            ^<HOST> - - \[[^\]]*\] "(?:GET|POST|HEAD) (?!/(?:ocs|remote\.php|index\.php/|status\.php|public\.php|apps/))(?:/\.env|/\.git/|[^" ]*(?:\.php\d?|wp-|xmlrpc|/administrator/|com_|/plugins/editors/|/media/(?:system|jui)/|phpmyadmin|cgi-bin))[^"]*" (?:400|401|403|404)\b
                        ^<HOST> - - \[[^\]]*\] "POST /index\.php\?option=com_(?:jce|sppagebuilder|media|fabrik)'';
          ignoreregex = "";
        };
        settings = {
          enabled = true;
          backend = "auto";
          port = "http,https";
          logpath = "/var/log/nginx/access.log";
          maxretry = 5;
          findtime = "10m";
          bantime = "1d";
        };
      };
    };
  };
}
