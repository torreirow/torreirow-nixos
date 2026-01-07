{ config, pkgs, ... }:

{
  virtualisation.oci-containers = {
    backend = "docker";

    containers.vaultwarden = {
      image = "vaultwarden/server:latest";
      environment = {
        DOMAIN = "https://vw.toorren.net";
        ROCKET_PORT = "8080";
        ROCKET_ADDRESS = "127.0.0.1";
        TZ = "Europe/Amsterdam";
        SIGNUPS_ALLOWED = "false";
        INVITATIONS_ALLOWED = "true";
      };
      volumes = [
        "/var/lib/vaultwarden:/data"
      ];
      extraOptions = [
        "--network=host"
        "--read-only"
        "--cap-drop=ALL"
        "--security-opt=no-new-privileges"
      ];
    };
  };


  services.nginx.virtualHosts."vw.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";

    # API and 2FA connector endpoints - no restrictive headers for external embedding
    locations."~ ^/(api|identity|two-factor|connectors)" = {
      proxyPass = "http://127.0.0.1:8080";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_buffering off;
        proxy_request_buffering off;

        # Basic security headers only (no CSP or X-Frame-Options for 2FA compatibility)
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "same-origin" always;
      '';
    };

    # Rate limiting specifically on login endpoint
    locations."= /identity/connect/token" = {
      proxyPass = "http://127.0.0.1:8080";
      extraConfig = ''
        limit_req zone=vwlogin burst=10 nodelay;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Basic security headers only
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "same-origin" always;
      '';
    };

    locations."/admin" = {
      proxyPass = "http://127.0.0.1:8080";
      extraConfig = ''
        # Authelia authentication required
        auth_request /authelia;
        error_page 401 = @authelia_portal;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };

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

    locations."@authelia_portal" = {
      extraConfig = ''
        return 302 https://auth.toorren.net/?rd=$scheme://$http_host$request_uri;
      '';
    };

    locations."/" = {
      proxyPass = "http://127.0.0.1:8080";
      proxyWebsockets = true;

      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_buffering off;
        proxy_request_buffering off;

        client_max_body_size 10M;

        # Security headers - only for non-API paths
        # Use a map to conditionally add headers based on URI
        set $add_security_headers 1;
        if ($request_uri ~* "^/(api|identity|two-factor|connectors|notifications)") {
          set $add_security_headers 0;
        }

        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "same-origin" always;
      '';
    };
  };


  #services.nginx.virtualHosts."vw.toorren.net" = {
  #  forceSSL = true;
  #  useACMEHost = "toorren.net";
  #  locations = {
  #    "/" = {
  #      proxyPass = "http://127.0.0.1:8080";
  #      proxyWebsockets = true;
  #    };
  #  };
  #};

}
