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
      "/data/external/invoiceplane/templates:/var/www/html/application/views/invoice_templates"
      "/data/external/invoiceplane/quote_templates:/var/www/html/application/views/quote_templates"
      "/data/external/invoiceplane/css/custom-pdf.css:/var/www/html/assets/core/css/custom-pdf.css"
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
    "d /data/external/invoiceplane/templates 0755 root root -"
    "d /data/external/invoiceplane/quote_templates 0755 root root -"
    "d /data/external/invoiceplane/css 0755 root root -"
  ];

  # Fix for Docker image: copy htaccess to .htaccess after container starts
  # The REMOVE_INDEXPHP=true env var doesn't work properly in this image
  systemd.services.docker-invoiceplane.serviceConfig.ExecStartPost =
    "${pkgs.bash}/bin/bash -c 'sleep 3 && ${pkgs.docker}/bin/docker exec invoiceplane cp /var/www/html/htaccess /var/www/html/.htaccess || true'";

  # Nginx reverse proxy (public access - no authentication)
  services.nginx.virtualHosts."invoices.wereldvanbegrip.nl" = {
    useACMEHost = "wereldvanbegrip.nl";
    forceSSL = true;
    locations = {
      "/" = {
        proxyPass = "http://127.0.0.1:8092";
        proxyWebsockets = true;
        extraConfig = ''
          # Upload size limit (proxy headers are set by nginx recommendedProxySettings)
          client_max_body_size 20M;
        '';
      };
    };
  };
}
