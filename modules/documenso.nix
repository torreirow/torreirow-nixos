{ config, pkgs, ... }:

{
  # Agenix secret for Documenso environment variables
  age.secrets.documenso-env = {
    file = ../secrets/documenso-env.age;
    path = "/run/agenix/documenso-env";
    mode = "0400";
  };

  # Documenso - Open source DocuSign alternative
  virtualisation.oci-containers.containers.documenso = {
    image = "documenso/documenso:latest";
    environment = {
      # Public URLs (not sensitive)
      NEXTAUTH_URL = "https://documenso.toorren.net";
      NEXT_PUBLIC_WEBAPP_URL = "https://documenso.toorren.net";

      # All sensitive data (DB credentials, secrets) loaded from agenix via --env-file

      # Optional: Email configuration (configure later)
      # NEXT_PRIVATE_SMTP_HOST = "smtp.example.com";
      # NEXT_PRIVATE_SMTP_PORT = "587";
      # NEXT_PRIVATE_SMTP_USERNAME = "your-email@example.com";
      # NEXT_PRIVATE_SMTP_PASSWORD = "your-smtp-password";

      TZ = "Europe/Amsterdam";
    };
    volumes = [
      "/data/external/documenso:/app/data"
    ];
    ports = [
      "127.0.0.1:8089:3000"  # Documenso web interface
    ];
    extraOptions = [
      "--add-host=host.docker.internal:host-gateway"  # Allow container to reach host PostgreSQL
      "--env-file=${config.age.secrets.documenso-env.path}"  # Load secrets from agenix
    ];
  };

  # Create documenso data directory
  systemd.tmpfiles.rules = [
    "d /data/external/documenso 0755 root root -"
  ];

  # Open firewall for Documenso (local only)
  networking.firewall.allowedTCPPorts = [ 8089 ];

  # Nginx reverse proxy
  services.nginx.virtualHosts."documenso.toorren.net" = {
    useACMEHost = "toorren.net";
    forceSSL = true;
    locations = {
      "/" = {
        proxyPass = "http://127.0.0.1:8089";
        proxyWebsockets = true;
        extraConfig = ''
          auth_request /authelia;
          error_page 401 = @authelia_portal;

          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };

      "@authelia_portal" = {
        extraConfig = ''
          return 302 https://auth.toorren.net/?rd=$scheme://$http_host$request_uri;
        '';
      };

      "/authelia" = {
        proxyPass = "http://127.0.0.1:9091/api/verify";
        extraConfig = ''
          internal;
          proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
          proxy_set_header X-Forwarded-For $remote_addr;
          proxy_set_header Content-Length "";
          proxy_pass_request_body off;
        '';
      };
    };
  };
}
