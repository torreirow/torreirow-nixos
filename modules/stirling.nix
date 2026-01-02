{ config, pkgs, ... }:

{
  virtualisation.oci-containers.containers.stirling-pdf = {
    image = "stirlingtools/stirling-pdf:latest";
    autoStart = true;

    ports = [
      "127.0.0.1:8084:8080"
    ];

    environment = {
      # Basis configuratie
      DISABLE_SECURITY = "false";
      LANGS = "en_GB,nl_NL";
    };

    volumes = [
      "/data/external/stirling-pdf:/usr/share/stirling-pdf/data"
    ];
  };

  # Zorg dat data directory bestaat
  systemd.tmpfiles.rules = [
    "d /data/external/stirling-pdf 0755 root root -"
  ];

services.nginx.virtualHosts."pdf.toorren.net" = {
  enableACME = true;
  forceSSL = true;

  locations."/" = {
    proxyPass = "http://127.0.0.1:8083";

    extraConfig = ''
      proxy_http_version 1.1;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;

      client_max_body_size 500m;
    '';
  };
};


}
