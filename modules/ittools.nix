{ config, pkgs, ... }:

{
  # Enable OCI container support (compatible with Docker)
  virtualisation.oci-containers = {
    backend = "docker"; # or "podman" if you prefer
    
    containers = {
      it-tools = {
        image = "corentinth/it-tools:latest";
        
        # Port mapping: host:container
        ports = [
          "8085:80"
        ];
        
        # Optional: Add labels for better organization
        labels = {
          "app" = "it-tools";
          "description" = "IT-Tools - Handy tools for developers";
        };
        
         environment = {
           TZ = "Europe/Amsterdam";
         };
        
      };
    };
  };

  services.nginx.virtualHosts."ittools.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";

    # JS-bestanden: vervang de externe CDN-URL voor figlet-fonts met een lokaal pad
    locations."~* ^/assets/.*\\.js$" = {
      proxyPass = "http://127.0.0.1:8085";
      extraConfig = ''
        auth_request /authelia;
        error_page 401 = @authelia_portal;

        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Accept-Encoding "";

        sub_filter '//unpkg.com/figlet@1.6.0/fonts/' '/figlet-fonts/';
        sub_filter_once off;
        sub_filter_types application/javascript;
      '';
    };

    # Proxy figlet-fonts via onze nginx, browser hoeft niet naar unpkg.com
    locations."/figlet-fonts/" = {
      proxyPass = "https://unpkg.com/figlet@1.6.0/fonts/";
      extraConfig = ''
        proxy_ssl_server_name on;
        proxy_set_header Host unpkg.com;
        proxy_set_header Accept-Encoding "";
        proxy_cache_valid 200 365d;
        add_header Cache-Control "public, max-age=31536000, immutable";
      '';
    };

    locations."/" = {
      proxyPass = "http://127.0.0.1:8085";
      proxyWebsockets = false;
      extraConfig = ''
        auth_request /authelia;
        error_page 401 = @authelia_portal;

        proxy_http_version 1.1;
        proxy_set_header Connection "";

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
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header Content-Length "";
        proxy_pass_request_body off;
      '';
    };
  };

  
}
