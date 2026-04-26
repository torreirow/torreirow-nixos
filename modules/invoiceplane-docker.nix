{ config, pkgs, ... }:

{
  # Agenix secret for InvoicePlane environment variables
  age.secrets.invoiceplane-env = {
    file = ../secrets/invoiceplane-env.age;
    path = "/run/agenix/invoiceplane-env";
    mode = "0400";
  };

  # InvoicePlane - Open source invoicing platform
  virtualisation.oci-containers.containers.invoiceplane = {
    image = "funktionslust/invoiceplane:latest";
    volumes = [
      "/data/external/invoiceplane:/var/www/html/uploads"
    ];
    ports = [
      "127.0.0.1:8092:80"  # InvoicePlane web interface
    ];
    extraOptions = [
      "--add-host=host.docker.internal:host-gateway"  # Allow container to reach host MariaDB
      "--env-file=${config.age.secrets.invoiceplane-env.path}"  # Load secrets from agenix
    ];
  };


  # Create invoiceplane data directory
  systemd.tmpfiles.rules = [
    "d /data/external/invoiceplane 0755 root root -"
  ];

  # Fix for Docker image: copy htaccess to .htaccess after container starts
  # The REMOVE_INDEXPHP=true env var doesn't work properly in this image
  systemd.services.docker-invoiceplane.serviceConfig.ExecStartPost =
    "${pkgs.bash}/bin/bash -c 'sleep 3 && ${pkgs.docker}/bin/docker exec invoiceplane cp /var/www/html/htaccess /var/www/html/.htaccess || true'";

  # Nginx reverse proxy with Authelia authentication
  services.nginx.virtualHosts."invoices.toorren.net" = {
    useACMEHost = "toorren.net";
    forceSSL = true;
    locations = {
      "/" = {
        proxyPass = "http://127.0.0.1:8092";
        proxyWebsockets = true;
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

          # Upload size limit (proxy headers are set by nginx recommendedProxySettings)
          client_max_body_size 20M;
        '';
      };

      # Authelia redirect named location
      "@authelia_portal" = {
        extraConfig = ''
          return 302 https://auth.toorren.net/?rd=$scheme://$http_host$request_uri;
        '';
      };

      # Authelia authentication endpoint
      "/authelia" = {
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
