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
      HOST = "onzeovereenkomst.wereldvanbegrip.nl";

      # Force SSL since we're behind HTTPS reverse proxy
      FORCE_SSL = "true";

      # All sensitive data (DB credentials, secrets) loaded from agenix via --env-file

      TZ = "Europe/Amsterdam";
    };
    volumes = [
      "/data/external/docseal:/data"
      # Custom login template
      "/data/external/docseal/custom-templates/devise/sessions/new.html.erb:/app/app/views/devise/sessions/new.html.erb:ro"
      # Custom landing page
      "/data/external/docseal/custom-templates/pages/landing.html.erb:/app/app/views/pages/landing.html.erb:ro"
      # Custom navbar title (logo)
      "/data/external/docseal/custom-templates/shared/_title.html.erb:/app/app/views/shared/_title.html.erb:ro"
      # Custom assets (logo, etc)
      "/data/external/docseal/custom-assets:/app/public/custom:ro"
      # Replace apple-icon with WvB logo
      "/data/external/docseal/custom-assets/apple-icon-180x180.png:/app/public/apple-icon-180x180.png:ro"
    ];
    ports = [
      "127.0.0.1:8090:3000"  # DocSeal web interface
    ];
    extraOptions = [
      "--add-host=host.docker.internal:host-gateway"  # Allow container to reach host PostgreSQL
      "--env-file=${config.age.secrets.docseal-env.path}"  # Load secrets from agenix
    ];
  };

  # Create docseal data directories
  systemd.tmpfiles.rules = [
    "d /data/external/docseal 0755 root root -"
    "d /data/external/docseal/custom-templates/devise/sessions 0755 root root -"
    "d /data/external/docseal/custom-templates/pages 0755 root root -"
    "d /data/external/docseal/custom-templates/shared 0755 root root -"
    "d /data/external/docseal/custom-assets 0755 root root -"
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

  # Nginx reverse proxy (without Authelia - public access)
  services.nginx.virtualHosts."onzeovereenkomst.wereldvanbegrip.nl" = {
    useACMEHost = "wereldvanbegrip.nl";
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8090";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}
