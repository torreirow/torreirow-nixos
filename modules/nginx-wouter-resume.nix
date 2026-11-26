{ config, pkgs, ... }:

let
  # Kleine broker die Cap-tokens verifieert voordat de PDF wordt uitgeleverd.
  # De PDF's staan wel in de webroot (release.sh deployt ze daar), maar nginx
  # blokkeert directe toegang; alleen deze service leest ze van schijf.
  brokerPort = 8787;
in
{
  # Cap key-secret van site key a9194a3d45 (agenix; nooit plaintext in de repo).
  age.secrets.cap-cv-secret = {
    file = ../secrets/cap-cv-secret.age;
    path = "/run/secrets/cap-cv-secret";
    owner = "cv-download";
    group = "cv-download";
    mode = "0400";
  };

  users.groups.cv-download = { };
  users.users.cv-download = {
    isSystemUser = true;
    group = "cv-download";
    # /run/keys (waar agenix de secrets neerzet) is root:keys 0750.
    extraGroups = [ "keys" ];
  };

  systemd.services.cv-download = {
    description = "CV-downloadbroker (Cap siteverify)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${./cv-download-broker.py}";
      User = "cv-download";
      Group = "cv-download";
      Restart = "on-failure";
      RestartSec = 2;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadOnlyPaths = [ "/var/www/cv-wouter/uploads" ];
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
    };
  };

  services.nginx = {
    # Canonieke host: statische Hugo-build van de CV-site.
    virtualHosts."wouter-resume.toorren.net" = {
      root = "/var/www/cv-wouter";

      forceSSL = true;
      useACMEHost = "toorren.net";

      locations."/" = {
        tryFiles = "$uri $uri/ =404";
      };

      # Downloads alleen via de broker (Cap-token verplicht).
      locations."/download" = {
        proxyPass = "http://127.0.0.1:${toString brokerPort}";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          client_max_body_size 8k;
          add_header Cache-Control "no-store";
        '';
      };

      # Geen directe toegang tot de PDF's meer.
      locations."~* ^/uploads/.*\\.pdf$" = {
        return = "404";
      };

      extraConfig = ''
        index index.html;
      '';
    };

    # Oude naam: permanent doorverwijzen, pad en query blijven behouden.
    virtualHosts."cv-wouter.toorren.net" = {
      forceSSL = true;
      useACMEHost = "toorren.net";

      locations."/" = {
        return = "301 https://wouter-resume.toorren.net$request_uri";
      };
    };
  };
}
