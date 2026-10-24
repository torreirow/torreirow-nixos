{ config, pkgs, ... }:

{
  virtualisation.oci-containers.containers.infcloud = {
    image = "ckulka/infcloud:experimental";
    autoStart = true;

    ports = [
      "127.0.0.1:8082:80"
    ];

    # Override config.js: hardcode Baikal dav.php URL instead of auto-detected caldav.php
    volumes = [
      "${./infcloud-config.js}:/usr/share/nginx/infcloud/config.js:ro"
    ];
  };

  virtualisation.oci-containers.containers.baikal = {
    # https://github.com/torreirow/baikal-php: upstream 0.10.1 (nginx) met PHP 8.3.36 i.p.v.
    # 8.1 (PHP2Shell). Upstream heeft geen image met een gepatchte PHP; terug zodra dat er is.
    image = "ghcr.io/torreirow/baikal-php@sha256:46d2d8aeda5128856c9a6ddb26327d0e48d48783de3dc7cbfb3b5beacb6fe5df"; # PHP 8.3.36
    autoStart = true;

    ports = [
      "127.0.0.1:8081:80"
    ];

    volumes = [
      "/var/lib/baikal/config:/var/www/baikal/config"
      "/var/lib/baikal/data:/var/www/baikal/Specific"
    ];
  };

  # Zorg dat de directories bestaan
  systemd.tmpfiles.rules = [
    "d /var/lib/baikal 0755 root root -"
    "d /var/lib/baikal/config 0755 root root -"
    "d /var/lib/baikal/data 0755 root root -"
  ];

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts."contacts.toorren.net" = {
      useACMEHost = "toorren.net";
      forceSSL = true;

      locations."/" = {
        proxyPass = "http://127.0.0.1:8082";
        proxyWebsockets = true;

        # Authelia forward authentication
        extraConfig = ''
          auth_request /authelia;
          auth_request_set $user $upstream_http_remote_user;
          auth_request_set $groups $upstream_http_remote_groups;
          auth_request_set $name $upstream_http_remote_name;
          auth_request_set $email $upstream_http_remote_email;

          error_page 401 = @authelia_portal;

          proxy_set_header Remote-User $user;
          proxy_set_header Remote-Groups $groups;
          proxy_set_header Remote-Name $name;
          proxy_set_header Remote-Email $email;
        '';
      };

      # Authelia redirect named location
      # Proxeer CalDAV/CardDAV endpoints naar Baikal
      locations."~ ^/(cal|card|dav)\\.php" = {
        proxyPass = "http://127.0.0.1:8081";
        proxyWebsockets = false;
      };

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
          proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
          proxy_set_header X-Forwarded-Method $request_method;
          proxy_set_header X-Forwarded-Host $http_host;
          proxy_set_header X-Forwarded-Uri $request_uri;
          proxy_set_header X-Forwarded-For $remote_addr;
          proxy_set_header Content-Length "";
          proxy_pass_request_body off;
        '';
      };
    };

    virtualHosts."adresses.toorren.net" = {
      forceSSL = true;
      useACMEHost = "toorren.net";

      locations."/" = {
        proxyPass = "http://127.0.0.1:8081";
        proxyWebsockets = false;

        extraConfig = ''
          dav_methods     PUT DELETE MKCOL COPY MOVE;
          dav_ext_methods PROPFIND OPTIONS;
          rewrite         ^/.well-known/caldav /cal.php redirect;
          rewrite         ^/.well-known/carddav /card.php redirect;
        '';
      };
    };
  };
}

