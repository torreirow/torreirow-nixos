{ config, pkgs, ... }:

# File Drop op upload.toorren.net: uploadpagina met verplichte naam/e-mail en Cap-captcha.
# De Go-dienst (pkgs/filedrop) streamt de bestanden via de publieke WebDAV van een Nextcloud
# File Drop-share (account nxceghmedia, map eghuploads) in een submap per inzending en meldt
# elke upload via Signal. De share-link zelf wordt nooit getoond. Zie docs/filedrop.md.

let
  port = 8102;
  maxMB = 25;
  # Cap site-key (publiek) van de site-key "filedrop" op cap.toorren.net.
  capSiteKey = "92c7e198d7";

  filedropPkg = pkgs.callPackage ../pkgs/filedrop { };
in
{
  imports = [ ./signal-numbers.nix ];

  # Inhoud (env-file): CAP_SECRET=<key-secret> en NEXTCLOUD_SHARE_TOKEN=<token uit de share-link>
  age.secrets.filedrop-env = {
    file = ../secrets/filedrop-env.age;
    mode = "0400";
  };

  systemd.services.filedrop = {
    description = "File Drop upload-formulier naar Nextcloud";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "docker-signal-cli.service" ];
    wants = [ "network-online.target" ];

    environment = {
      FILEDROP_PORT = toString port;
      CAP_URL = "https://cap.toorren.net/${capSiteKey}";
      NEXTCLOUD_URL = "https://nxc.toorren.net";
      SIGNAL_API = "http://127.0.0.1:8088/v2/send";
      MAX_BYTES = toString (maxMB * 1024 * 1024);
      LARGE_FILE_CONTACT = "taakgroepbeeldengeluid@evangelischegemeente.org";
      # Quota over 24 uur (sliding window), alleen na geslaagde captcha. Zie docs/filedrop.md.
      LIMIT_PER_IP_HOUR = "3";
      LIMIT_PER_IP_DAY = "10";
      LIMIT_TOTAL_DAY = "40";
      LIMIT_BYTES_DAY = toString (1024 * 1024 * 1024);
      SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    };

    serviceConfig = {
      ExecStart = "${filedropPkg}/bin/filedrop";
      # SIGNAL_SENDER/SIGNAL_RECIPIENT uit modules/signal-numbers.nix
      EnvironmentFile = [
        config.age.secrets.filedrop-env.path
        config.age.secrets.signal-numbers.path
      ];
      Restart = "on-failure";
      RestartSec = "5s";

      # Hardening
      DynamicUser = true;
      StateDirectory = "filedrop"; # ratelimit.json
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
    };
  };

  services.nginx = {
    commonHttpConfig = ''
      limit_req_zone $binary_remote_addr zone=filedrop:10m rate=6r/m;
    '';

    virtualHosts."upload.toorren.net" = {
      forceSSL = true;
      useACMEHost = "toorren.net";

      locations."/".proxyPass = "http://127.0.0.1:${toString port}";

      locations."= /upload" = {
        proxyPass = "http://127.0.0.1:${toString port}";
        extraConfig = ''
          limit_except POST { deny all; }
          limit_req zone=filedrop burst=3 nodelay;
          # Ruimer dan de app-limiet, zodat filedrop zelf de nette melding (met contactadres) geeft.
          client_max_body_size ${toString (maxMB + 5)}m;
          client_body_timeout 3600s;
          proxy_request_buffering off;
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
        '';
      };
    };
  };
}
