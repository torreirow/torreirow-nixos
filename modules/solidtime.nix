{
  config,
  lib,
  pkgs,
  ...
}:

# Solidtime (tijdregistratie) als losstaande NixOS-module: app, scheduler, queue,
# gotenberg en eigen PostgreSQL in containers op één bridge-netwerk, met nginx
# ervoor. Geen afhankelijkheid van elastinix/tfvars; alles is via opties te
# overschrijven.
#
# Het env-bestand (naar upstream laravel.env.example) moet minimaal bevatten:
#   APP_NAME, APP_ENV=production, APP_DEBUG=false, APP_KEY,
#   APP_URL=https://<domain>, APP_FORCE_HTTPS=true,
#   TRUSTED_PROXIES=0.0.0.0/0 (app luistert alleen op loopback via nginx),
#   PASSPORT_PRIVATE_KEY, PASSPORT_PUBLIC_KEY, SUPER_ADMINS,
#   DB_CONNECTION=pgsql, DB_HOST=solidtime-db, DB_PORT=5432,
#   DB_SSL_MODE=prefer, DB_DATABASE, DB_USERNAME, DB_PASSWORD,
#   POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD   (alleen bij enableDatabase)
# Bij manageLocalDatabase wijst DB_HOST naar de host (bijv. 192.168.2.52) en
# wordt de rol/database daar aangemaakt met DB_PASSWORD.
# Optioneel: MAIL_*, QUEUE_CONNECTION=database,
# FILESYSTEM_DISK=local, PUBLIC_FILESYSTEM_DISK=public,
# GOTENBERG_URL=http://solidtime-gotenberg:3000
#
# Agenix-secret aanmaken:
#   ragenx -e secrets/solidtime-env.age
#
# Let op: geen quotes om waarden heen. `docker run --env-file` (anders dan
# docker compose) stript die niet, waardoor Postgres LETTERLIJK '"solidtime"'
# als gebruikersnaam krijgt en initdb faalt.

let
  cfg = config.services.solidtime;

  inherit (config.virtualisation.oci-containers) backend;
  backendBin = "${pkgs.${backend}}/bin/${backend}";

  networkName = "solidtime-network";
  dataDir = "/data/external/solidtime";

  # Alle solidtime-containers delen dezelfde mounts en omgeving.
  common = {
    image = "solidtime/solidtime:${cfg.version}";
    user = "1000:1000";
    dependsOn = [ ];
    volumes = [
      "app-storage:/var/www/html/storage"
      "${dataDir}/logs:/var/www/html/storage/logs"
      "${dataDir}/app-storage:/var/www/html/storage/app"
    ];
    environmentFiles = [ cfg.environmentFile ];
    extraOptions = [
      "--network=${networkName}"
      "--add-host=host.docker.internal:host-gateway"
    ];
  };
in
{
  options.services.solidtime = {
    enable = lib.mkEnableOption "Solidtime tijdregistratie";

    version = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = "Image-tag van solidtime/solidtime. Pin een versie voor productie.";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "solidtime.toorren.net";
      description = "Publieke hostnaam voor de nginx-vhost.";
    };

    acmeHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "toorren.net";
      description = ''
        Naam van het bestaande security.acme.certs.<naam> (wildcard-cert).
        Op null zetten laat de vhost zelf een certificaat aanvragen.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Loopback-poort waarop de app-container naar buiten luistert.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      default = "/run/agenix/solidtime-env";
      description = "Pad naar het env-bestand met app- en database-instellingen.";
    };

    enableAgenix = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Declareer het agenix-secret secrets/solidtime-env.age.";
    };

    enableDatabase = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Start een eigen PostgreSQL-container (solidtime-db). Uitzetten als de
        app naar een externe database wijst; pas dan ook DB_HOST in het env-bestand aan.
      '';
    };

    manageLocalDatabase = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Richt de database en rol `solidtime` in op de PostgreSQL van de host zelf
        (enableDatabase moet dan uit staan). Zet het wachtwoord uit DB_PASSWORD in
        het env-bestand. Vereist ook een pg_hba-regel voor het Docker-subnet; die
        staat op malandro in modules/docseal.nix (datbestand overschrijft de hele
        authentication-lijst).
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        # Bridge-netwerk vóór de containers starten.
        system.activationScripts.solidtimeNetwork = ''
          ${backendBin} network inspect ${networkName} >/dev/null 2>&1 || \
          ${backendBin} network create --driver bridge ${networkName}
        '';

        # De containers draaien als uid/gid 1000; laat de bind-mounts toekomen.
        systemd.tmpfiles.rules = [
          "d ${dataDir} 0755 root root -"
          "d ${dataDir}/logs 0750 1000 1000 -"
          "d ${dataDir}/app-storage 0750 1000 1000 -"
        ];

        virtualisation.oci-containers.containers = {
          solidtime-app = common // {
            ports = [ "127.0.0.1:${toString cfg.port}:8000" ];
            environment = {
              CONTAINER_MODE = "http";
              # Migraties bij elke start; anders handmatig `php artisan migrate --force`.
              AUTO_DB_MIGRATE = "true";
            };
          };

          solidtime-scheduler = common // {
            environment.CONTAINER_MODE = "scheduler";
          };

          solidtime-queue = common // {
            environment = {
              CONTAINER_MODE = "worker";
              WORKER_COMMAND = "php /var/www/html/artisan queue:work";
            };
          };

          solidtime-gotenberg = {
            image = "gotenberg/gotenberg:8";
            dependsOn = [ ];
            extraOptions = [
              "--network=${networkName}"
              "--add-host=host.docker.internal:host-gateway"
            ];
          };
        };

        services.nginx.virtualHosts.${cfg.domain} =
          (if cfg.acmeHost != null then { useACMEHost = cfg.acmeHost; } else { enableACME = true; })
          // {
            forceSSL = true;
            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString cfg.port}";
              proxyWebsockets = true;
              extraConfig = ''
                client_max_body_size 25M;
              '';
            };
          };
      }

      (lib.mkIf cfg.enableAgenix {
        age.secrets.solidtime-env = {
          file = ../secrets/solidtime-env.age;
          path = "/run/agenix/solidtime-env";
          mode = "0400";
        };
      })

      (lib.mkIf cfg.enableDatabase {
        virtualisation.oci-containers.containers.solidtime-db = {
          image = "postgres:16-alpine";
          volumes = [ "solidtime-db:/var/lib/postgresql/data" ];
          environmentFiles = [ cfg.environmentFile ];
          extraOptions = [ "--network=${networkName}" ];
        };

        # App, scheduler en queue pas starten als de database-container bestaat.
        virtualisation.oci-containers.containers = {
          solidtime-app.dependsOn = [ "solidtime-db" ];
          solidtime-scheduler.dependsOn = [ "solidtime-db" ];
          solidtime-queue.dependsOn = [ "solidtime-db" ];
        };
      })

      (lib.mkIf cfg.manageLocalDatabase {
        assertions = [
          {
            assertion = !cfg.enableDatabase;
            message = "services.solidtime: manageLocalDatabase vereist enableDatabase = false.";
          }
        ];

        services.postgresql = {
          ensureDatabases = [ "solidtime" ];
          ensureUsers = [
            {
              name = "solidtime";
              ensureDBOwnership = true;
            }
          ];
        };

        # Wachtwoord uit het env-bestand naar de rol; idempotent bij elke switch.
        # Containers pas starten als het wachtwoord in de rol staat.
        systemd.services =
          {
            postgres-set-solidtime-password = {
              description = "Set PostgreSQL password for solidtime";
              after = [ "postgresql.service" ];
              requires = [ "postgresql.service" ];
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                Type = "oneshot";
              };

              script = ''
                envfile=${
                  lib.escapeShellArg (
                    if cfg.enableAgenix then config.age.secrets.solidtime-env.path else cfg.environmentFile
                  )
                }
                pw=$(${pkgs.gnused}/bin/sed -n 's/^DB_PASSWORD=//p' "$envfile")
                ${pkgs.util-linux}/bin/runuser -u postgres -- ${config.services.postgresql.package}/bin/psql -d postgres -v ON_ERROR_STOP=1 -v pw="$pw" <<'SQL'
                  ALTER ROLE solidtime WITH LOGIN PASSWORD :'pw';
                SQL
              '';
            };
          }
          // lib.genAttrs [
            "${backend}-solidtime-app"
            "${backend}-solidtime-scheduler"
            "${backend}-solidtime-queue"
          ] (_: {
            after = [ "postgres-set-solidtime-password.service" ];
            wants = [ "postgres-set-solidtime-password.service" ];
          });
      })
    ]
  );
}
