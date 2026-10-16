{ config, pkgs, ... }:

{
  # Agenix secret for InvoicePlane environment variables
  age.secrets.invoiceplane-env = {
    file = ../secrets/invoiceplane-env.age;
    path = "/run/agenix/invoiceplane-env";
    mode = "0400";
  };

  # InvoicePlane via Gabbaya: eigen build van de officiële release + patches
  # (https://github.com/torreirow/gabbaya). Vastgepind op digest; upgraden = nieuwe
  # digest kiezen, testen tegen een DB-kopie, dan de DB-update via /setup.
  virtualisation.oci-containers.containers.invoiceplane = {
    image = "ghcr.io/torreirow/gabbaya@sha256:623bd34388271193c20400130bcfef387efb934a04c27a2cd6290a6edb9e6ded"; # 1.7.2
    volumes = [
      "/data/external/invoiceplane-docker:/var/www/html/uploads"
      # ipconfig.php blijvend (Gabbaya linkt het vanuit /config de webroot in)
      "/data/external/invoiceplane-config:/config"
      # Eigen templates (WereldVanBegrip), alleen-lezen: sinds 1.7.2 worden templates
      # niet meer van schijf gescand maar via de CUSTOM_*-allowlist hieronder toegelaten.
      "/data/external/invoiceplane-templates:/custom-templates:ro"
      "/data/external/invoiceplane-docker/css/custom-pdf.css:/var/www/html/assets/core/css/custom-pdf.css"
      # Wereld van Begrip-favicon i.p.v. het InvoicePlane-icoon uit het image
      "/data/external/invoiceplane-docker/branding/favicon.png:/var/www/html/assets/core/img/favicon.png:ro"
    ];
    # Geen geheimen; die staan in het env-file. Waarden met -e gaan vóór het env-file.
    environment = {
      CUSTOM_TEMPLATES_FOLDER = "/custom-templates";
      CUSTOM_INVOICE_TEMPLATES_PDF = "WereldVanBegrip";
      CUSTOM_INVOICE_TEMPLATES_PUBLIC = "WereldVanBegrip_Web";
      CUSTOM_QUOTE_TEMPLATES_PDF = "WereldVanBegrip";
      CUSTOM_QUOTE_TEMPLATES_PUBLIC = "WereldVanBegrip_Web";
      # DB-update na een upgrade: tijdelijk SETUP_COMPLETED = "false" hier toevoegen,
      # rebuild, /setup doorlopen (achter Authelia), regel weer weg en rebuild.
    };
    ports = [
      "127.0.0.1:8092:80"  # InvoicePlane web interface
    ];
    extraOptions = [
      "--add-host=host.docker.internal:host-gateway"  # Allow container to reach host MariaDB
      "--env-file=${config.age.secrets.invoiceplane-env.path}"  # Load secrets from agenix
    ];
  };

  # www-data in de container is UID/GID 33. De .htaccess-workaround (ExecStartPost) is
  # niet meer nodig: het Gabbaya-entrypoint installeert .htaccess bij REMOVE_INDEXPHP=true.
  systemd.tmpfiles.rules = [
    "d /data/external/invoiceplane-docker 0775 33 33 -"
    "d /data/external/invoiceplane-config 0750 33 33 -"
    "d /data/external/invoiceplane-templates 0755 root root -"
    "d /data/external/invoiceplane-docker/css 0755 root root -"
    "d /data/external/invoiceplane-docker/branding 0755 root root -"
  ];

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
