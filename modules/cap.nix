{ config, pkgs, lib, ... }:

# Cap — self-hosted, privacy-first proof-of-work CAPTCHA (https://trycap.dev).
# Bedoeld als vervanger van Cloudflare Turnstile in modules/mailer.nix.
#
# Opzet (spike):
#   - cap        : de standalone server (Bun), image tiago2/cap:latest, poort 3000
#   - cap-valkey : Valkey 9 (Redis-compatible) store voor challenges/tokens/site-keys
#   Beide draaien op een eigen docker-netwerk `cap-net` zodat cap Valkey via de
#   containernaam kan bereiken. Valkey heeft een persistent volume, want de
#   site-key + secret worden dáár bewaard (anders ben je ze kwijt bij een restart).
#
# BOOTSTRAP (eenmalig, imperatief — Cap kent geen declaratieve key-provisioning):
#   1. Deploy deze module + het cap-admin-key secret, rebuild op malandro.
#   2. Open https://cap.toorren.net, log in met de ADMIN_KEY.
#   3. Maak een site-key aan; noteer de site-key (publiek) en de key-secret (privaat).
#   4. Zet de key-secret in agenix (secrets/cap-mailer-secret.age) voor de mailer.
#
# De ADMIN_KEY hoort als `ADMIN_KEY=<min. 32 tekens>` in het agenix env-file te staan.

let
  dataDir = "/data/external/cap";
  netName = "cap-net";
in
{
  #### Secret #######################################################
  age.secrets.cap-admin-key = {
    file = ../secrets/cap-admin-key.age;   # inhoud: ADMIN_KEY=....
    mode = "0400";
  };

  #### Data-map + docker-netwerk ####################################
  virtualisation.docker.enable = true;

  systemd.tmpfiles.rules = [
    "d ${dataDir} 0755 root root - -"
    # Valkey draait in de container als uid 999; de data-map moet door die uid
    # beschrijfbaar zijn, anders faalt de RDB-snapshot (Permission denied) en
    # blokkeert Valkey alle writes (stop-writes-on-bgsave-error).
    "d ${dataDir}/valkey 0755 999 999 - -"
  ];

  # Maak het user-defined netwerk aan zodat containers elkaar op naam vinden.
  systemd.services.init-cap-net = {
    description = "Create ${netName} docker network";
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.docker}/bin/docker network inspect ${netName} >/dev/null 2>&1 \
        || ${pkgs.docker}/bin/docker network create ${netName}
    '';
  };

  #### Containers ###################################################
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      cap-valkey = {
        image = "valkey/valkey:9-alpine";
        cmd = [ "--appendonly" "yes" ];
        volumes = [ "${dataDir}/valkey:/data" ];
        extraOptions = [ "--network=${netName}" ];
        autoStart = true;
      };

      cap = {
        image = "tiago2/cap:latest";
        # Alleen op loopback; nginx doet TLS + reverse proxy.
        ports = [ "127.0.0.1:3009:3000" ];
        environment = {
          REDIS_URL = "redis://cap-valkey:6379";
        };
        extraOptions = [
          "--network=${netName}"
          "--env-file=${config.age.secrets.cap-admin-key.path}"
        ];
        dependsOn = [ "cap-valkey" ];
        autoStart = true;
      };
    };
  };

  # Beide containers pas starten nadat het netwerk bestaat.
  systemd.services.docker-cap.after = [ "init-cap-net.service" ];
  systemd.services.docker-cap.requires = [ "init-cap-net.service" ];
  systemd.services.docker-cap-valkey.after = [ "init-cap-net.service" ];
  systemd.services.docker-cap-valkey.requires = [ "init-cap-net.service" ];

  #### Nginx reverse proxy ##########################################
  services.nginx.virtualHosts."cap.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";
    locations."/" = {
      proxyPass = "http://127.0.0.1:3009";
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
