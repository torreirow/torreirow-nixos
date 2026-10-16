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
    # Vastgepind op digest (2026-10-16): eigen templates/mounts zijn tegen deze versie getest.
    # Upgraden = bewust nieuwe digest kiezen en templates/settings-pagina nalopen.
    image = "funktionslust/invoiceplane@sha256:8fa4726ee8941da5e7376bd33e50cc1587e6f7951ddec81f181c7eeba0ae7283";
    volumes = [
      "/data/external/invoiceplane-docker:/var/www/html/uploads"
      "/data/external/invoiceplane-docker/templates:/var/www/html/application/views/invoice_templates"
      "/data/external/invoiceplane-docker/quote_templates:/var/www/html/application/views/quote_templates"
      "/data/external/invoiceplane-docker/css/custom-pdf.css:/var/www/html/assets/core/css/custom-pdf.css"
      # Wereld van Begrip-favicon i.p.v. het InvoicePlane-icoon uit het image
      "/data/external/invoiceplane-docker/branding/favicon.png:/var/www/html/assets/core/img/favicon.png:ro"
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
  # www-data in container is UID/GID 33, needs write access
  systemd.tmpfiles.rules = [
    "d /data/external/invoiceplane-docker 0775 33 33 -"
    "d /data/external/invoiceplane-docker/templates 0775 33 33 -"
    "d /data/external/invoiceplane-docker/quote_templates 0775 33 33 -"
    # De bind-mounts verbergen de pdf/ en public/ submappen uit het image; ontbreken ze,
    # dan crasht /settings (directory_map geeft false i.p.v. een array)
    "d /data/external/invoiceplane-docker/templates/pdf 0775 33 33 -"
    "d /data/external/invoiceplane-docker/templates/public 0775 33 33 -"
    "d /data/external/invoiceplane-docker/quote_templates/pdf 0775 33 33 -"
    "d /data/external/invoiceplane-docker/quote_templates/public 0775 33 33 -"
    "d /data/external/invoiceplane-docker/css 0755 root root -"
    "d /data/external/invoiceplane-docker/branding 0755 root root -"
  ];

  # Fix for Docker image: copy htaccess to .htaccess after container starts
  # The REMOVE_INDEXPHP=true env var doesn't work properly in this image
  systemd.services.docker-invoiceplane.serviceConfig.ExecStartPost =
    "${pkgs.bash}/bin/bash -c 'sleep 3 && ${pkgs.docker}/bin/docker exec invoiceplane cp /var/www/html/htaccess /var/www/html/.htaccess || true'";

  # Nginx reverse proxy. Beheer achter Authelia (groep invoiceplane, zie modules/authelia.nix);
  # alleen wat klanten nodig hebben is publiek: de gastweergave van facturen/offertes, de
  # assets daarvan en de logo-bestanden direct in /uploads/ (voor de mails).
  # Proxy-headers komen uit recommendedProxySettings -- niet handmatig zetten (dubbele Host → 400).
  services.nginx.virtualHosts."invoices.wereldvanbegrip.nl" = {
    useACMEHost = "wereldvanbegrip.nl";
    forceSSL = true;
    locations = {
      "/" = {
        proxyPass = "http://127.0.0.1:8092";
        proxyWebsockets = true;
        extraConfig = ''
          auth_request /authelia;
          error_page 401 = @authelia_portal;
          client_max_body_size 20M;
        '';
      };

      # Publiek: klantlinks uit de mails
      "/guest/".proxyPass = "http://127.0.0.1:8092";
      "/assets/".proxyPass = "http://127.0.0.1:8092";
      "~ ^/uploads/[^/]+\\.(png|jpe?g)$".proxyPass = "http://127.0.0.1:8092";

      "@authelia_portal".extraConfig = ''
        return 302 https://auth.wereldvanbegrip.nl/?rd=$scheme://$http_host$request_uri;
      '';

      "/authelia" = {
        proxyPass = "http://127.0.0.1:9091/api/verify";
        extraConfig = ''
          internal;
          proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
          proxy_set_header X-Forwarded-Method $request_method;
          proxy_set_header X-Forwarded-Uri $request_uri;
          proxy_pass_request_body off;
          proxy_set_header Content-Length "";
        '';
      };
    };
  };
}
