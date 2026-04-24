{ config, pkgs, ... }:

{
  # Agenix secret for DocSeal environment variables
  age.secrets.docseal-env = {
    file = ../secrets/docseal-env.age;
    path = "/run/agenix/docseal-env";
    mode = "0400";
  };

  # DocSeal - Open source document signing platform
  virtualisation.oci-containers.containers.docseal = {
    image = "docuseal/docuseal:latest";
    environment = {
      # Public URL
      HOST = "docseal.toorren.net";

      # All sensitive data (DB credentials, secrets) loaded from agenix via --env-file

      TZ = "Europe/Amsterdam";
    };
    volumes = [
      "/data/external/docseal:/data"
    ];
    ports = [
      "127.0.0.1:8090:3000"  # DocSeal web interface
    ];
    extraOptions = [
      "--add-host=host.docker.internal:host-gateway"  # Allow container to reach host PostgreSQL
      "--env-file=${config.age.secrets.docseal-env.path}"  # Load secrets from agenix
    ];
  };

  # Create docseal data directory
  systemd.tmpfiles.rules = [
    "d /data/external/docseal 0755 root root -"
  ];

  # PostgreSQL: Allow Docker container access
  services.postgresql.authentication = pkgs.lib.mkOverride 10 ''
    # Docker containers
    host docseal docseal 172.17.0.0/16 trust
    host paperless paperless 172.18.0.0/16 md5

    # Default rules
    local all postgres         peer map=postgres
    local all all              peer
    host  all all 127.0.0.1/32 md5
    host  all all ::1/128      md5
  '';

  # Nginx reverse proxy
  services.nginx.virtualHosts."docseal.toorren.net" = {
    useACMEHost = "toorren.net";
    forceSSL = true;
    locations = {
      "/" = {
        proxyPass = "http://127.0.0.1:8090";
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
