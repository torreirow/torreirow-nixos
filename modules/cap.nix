{ config, pkgs, lib, ... }:

# Cap — self-hosted, privacy-first proof-of-work CAPTCHA (https://trycap.dev).
# Bedoeld als vervanger van Cloudflare Turnstile in modules/mailer.nix.
#
# Opzet:
#   - cap        : de standalone server (Bun, heet sinds v4 `capd`), image tiago2/cap, poort 3000
#   - cap-valkey : Valkey 9 (Redis-compatible) store voor challenges/tokens/site-keys/sessies
#   Beide draaien op een eigen docker-netwerk `cap-net` zodat cap Valkey via de
#   containernaam kan bereiken. Valkey heeft een persistent volume, want de
#   site-key + secret worden dáár bewaard (anders ben je ze kwijt bij een restart).
#   Sinds v4 schrijft capd events (analytics) naar DuckDB in DATA_DIR; dat pad is
#   een eigen volume, anders is de historie weg bij elke container-herstart.
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
    # capd draait als uid 1000 (bun) en schrijft DuckDB + IP-databases in DATA_DIR.
    "d ${dataDir}/events 0755 1000 1000 - -"
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
        # Gepind op 4.0.12 (2026-11-12). De 4.0-build van 2026-11-09 crashte op
        # malandro's Celeron J3455 met "Illegal instruction": niet Bun, maar de
        # meegeleverde DuckDB 2.0 vereist AVX2+FMA. Sinds 4.0.10 gebruikt capd
        # DuckDB 1.4.5, dat zonder AVX2 werkt. Pas bijwerken nadat een nieuwe
        # build hier getest is.
        image = "tiago2/cap@sha256:e9cd4884f35ca6bcedb6a27fa92be55813bfe64fe2cae93a084ec8d20e1aebd5";
        # Alleen op loopback; nginx doet TLS + reverse proxy.
        ports = [ "127.0.0.1:3009:3000" ];
        volumes = [ "${dataDir}/events:/usr/src/app/data" ];
        environment = {
          # v4 hernoemde REDIS_URL naar VALKEY_URL; zonder deze regel valt capd
          # terug op redis://localhost:6379 en werkt het zonder foutmelding niet.
          VALKEY_URL = "redis://cap-valkey:6379";
          # DuckDB-limiet (default 256MB) klein houden: malandro swapt al.
          DUCKDB_MEMORY_LIMIT = "128MB";
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
        # capd rate-limit per client-IP. De documentatie schrijft $remote_addr voor
        # (niet $proxy_add_x_forwarded_for: dat is door de client aan te vullen) en
        # vraagt daarnaast de proxy-instelling in het dashboard.
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}
