{ config, pkgs, ... }:

{
  # Agenix secret for InvoicePlane environment variables
  age.secrets.invoiceplane-env = {
    file = ../secrets/invoiceplane-env.age;
    path = "/run/agenix/invoiceplane-env";
    mode = "0400";
  };

  # Client secret voor single sign-on (OIDC_CLIENT_SECRET=...); de hash staat bij de
  # Authelia-client "invoiceplane" in modules/authelia.nix.
  age.secrets.invoiceplane-oidc = {
    file = ../secrets/invoiceplane-oidc.age;
    path = "/run/agenix/invoiceplane-oidc";
    mode = "0400";
  };

  # InvoicePlane via Gabbaya: eigen build van de officiële release + patches
  # (https://github.com/torreirow/gabbaya). Vastgepind op digest; upgraden = nieuwe
  # digest kiezen, testen tegen een DB-kopie, dan de DB-update via /setup.
  virtualisation.oci-containers.containers.invoiceplane = {
    image = "ghcr.io/torreirow/gabbaya@sha256:b9b234d861116844654c747cfe2ee34b266b0c9f2e1d9f7e42e8bc7b39297cec"; # 1.7.2 + patches 0001-0004
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
      # Setup-wizard dubbel op slot (1.7.2 toont anders een "Security Warning"); het
      # env-file heeft nog DISABLE_SETUP=false, deze waarde gaat daar vóór.
      # DB-update na een upgrade: tijdelijk DISABLE_SETUP = "false" en
      # SETUP_COMPLETED = "false", rebuild, /setup doorlopen (achter Authelia), terug en rebuild.
      DISABLE_SETUP = "true";
      # Single sign-on via Authelia (Gabbaya patch 0004-oidc-sso). Overige opties
      # (auto-redirect, lokaal inloggen als noodroute) staan in Instellingen > Single sign-on.
      OIDC_ENABLED = "true";
      OIDC_PROVIDER_URL = "https://auth.wereldvanbegrip.nl";
      OIDC_CLIENT_ID = "invoiceplane";
    };
    ports = [
      "127.0.0.1:8092:80"  # InvoicePlane web interface
    ];
    extraOptions = [
      "--add-host=host.docker.internal:host-gateway"  # Allow container to reach host MariaDB
      "--env-file=${config.age.secrets.invoiceplane-env.path}"  # Load secrets from agenix
      "--env-file=${config.age.secrets.invoiceplane-oidc.path}"  # OIDC_CLIENT_SECRET
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

      # Publiek: klantlinks uit de mails. Alleen GET/HEAD: het image draait PHP 8.1 (mod_php),
      # dat geen fix krijgt voor PHP2Shell (CVE-2026-109618/109619, multipart-POST). Ook
      # /assets/ en /uploads/: niet-bestaande paden routeert .htaccess naar index.php.
      # Weghalen zodra Gabbaya op PHP >= 8.2.35 draait (zie docs/invoiceplane.md).
      "/guest/" = {
        proxyPass = "http://127.0.0.1:8092";
        extraConfig = "limit_except GET { deny all; }";
      };
      "/assets/" = {
        proxyPass = "http://127.0.0.1:8092";
        extraConfig = "limit_except GET { deny all; }";
      };
      "~ ^/uploads/[^/]+\\.(png|jpe?g)$" = {
        proxyPass = "http://127.0.0.1:8092";
        extraConfig = "limit_except GET { deny all; }";
      };

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
