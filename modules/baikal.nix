{ config, pkgs, ... }:

{
  virtualisation.oci-containers.containers.infcloud = {
    image = "ckulka/infcloud:experimental";
    autoStart = true;

    ports = [
      "127.0.0.1:8082:80"
    ];
  };

  virtualisation.oci-containers.containers.baikal = {
    image = "ckulka/baikal:nginx";
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
          # Forward authentication to Authelia
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

          # Standard proxy headers
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
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

