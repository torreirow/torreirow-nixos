{ config, pkgs, ... }:

# MarkMySteps (https://github.com/Marukiee/MarkMySteps): self-hosted reis-tracker /
# Polarsteps-vervanger op markmysteps.toorren.net. Proef naast OwnSteps (reis.toorren.net).
#
# Upstream publiceert geen images, alleen Dockerfiles. markmysteps-images bouwt ze op malandro
# uit de vastgepinde bron in de nix store; een image dat al bestaat wordt niet opnieuw gebouwd.
#
# Bewust GEEN Authelia ervoor: de Android-app praat met /api via een eigen token en de
# thuisblijvers openen een privélink zonder account. MarkMySteps heeft een eigen login (+ 2FA).
let
  version = "v264";
  src = pkgs.fetchFromGitHub {
    owner = "Marukiee";
    repo = "MarkMySteps";
    rev = "89472861ba850665c512b06aa7ee4552f71c04b4";
    hash = "sha256-/D/2KXI6aZLdPgWJL6DhxoxFvR7tHvE70Zs4diKfdvc=";
  };

  netName = "markmysteps";
  subnet = "172.22.0.0/16";
  gateway = "172.22.0.1";
  baseDir = "/data/external/markmysteps";

  apiImage = "localhost/markmysteps-api:${version}";
  webImage = "localhost/markmysteps-web:${version}";
in
{
  # POSTGRES_PASSWORD, DATABASE_URL (met dat wachtwoord), JWT_SECRET en MASTER_ENCRYPTION_KEY.
  age.secrets.markmysteps-env = {
    file = ../secrets/markmysteps-env.age;
    path = "/run/agenix/markmysteps-env";
    mode = "0400";
  };

  systemd.tmpfiles.rules = [
    "d ${baseDir} 0755 root root - -"
    "d ${baseDir}/db 0700 70 70 - -"
  ];

  systemd.services.init-markmysteps-net = {
    description = "Create ${netName} docker network (${subnet})";
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.docker}/bin/docker network inspect ${netName} >/dev/null 2>&1 \
        || ${pkgs.docker}/bin/docker network create --subnet ${subnet} --gateway ${gateway} ${netName}
    '';
  };

  # Upgraden = version/rev/hash ophogen; de nieuwe tag wordt dan bij de volgende start gebouwd.
  systemd.services.markmysteps-images = {
    description = "Build MarkMySteps ${version} images";
    after = [ "docker.service" "network-online.target" ];
    requires = [ "docker.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # pnpm install + vite build; ruim genoeg op de eerste keer.
      TimeoutStartSec = "45min";
    };
    script = ''
      for part in api web; do
        image="localhost/markmysteps-$part:${version}"
        ${pkgs.docker}/bin/docker image inspect "$image" >/dev/null 2>&1 && continue
        ${pkgs.docker}/bin/docker build -t "$image" -f ${src}/docker/$part.Dockerfile ${src}
      done
    '';
  };

  systemd.services.docker-markmysteps-db = {
    after = [ "init-markmysteps-net.service" ];
    requires = [ "init-markmysteps-net.service" ];
  };
  systemd.services.docker-markmysteps-api = {
    after = [ "init-markmysteps-net.service" "markmysteps-images.service" ];
    requires = [ "init-markmysteps-net.service" "markmysteps-images.service" ];
  };
  systemd.services.docker-markmysteps-web = {
    after = [ "init-markmysteps-net.service" "markmysteps-images.service" ];
    requires = [ "init-markmysteps-net.service" "markmysteps-images.service" ];
  };

  virtualisation.oci-containers.containers = {
    markmysteps-db = {
      image = "docker.io/postgis/postgis:16-3.5-alpine";
      autoStart = true;
      # Geen poorten: alleen bereikbaar op het markmysteps-netwerk.
      volumes = [ "${baseDir}/db:/var/lib/postgresql/data" ];
      environment = {
        POSTGRES_DB = "markmysteps";
        POSTGRES_USER = "markmysteps";
      };
      environmentFiles = [ config.age.secrets.markmysteps-env.path ];
      extraOptions = [ "--network=${netName}" "--network-alias=db" ];
    };

    markmysteps-api = {
      image = apiImage;
      pull = "never";
      autoStart = true;
      dependsOn = [ "markmysteps-db" ];
      environment = {
        NODE_ENV = "production";
        TZ = "Europe/Amsterdam";
        API_PORT = "3000";
        POSTGRES_HOST = "db";
        POSTGRES_PORT = "5432";
        POSTGRES_DB = "markmysteps";
        POSTGRES_USER = "markmysteps";
        WEB_ORIGIN = "https://markmysteps.toorren.net";
        JWT_EXPIRES_IN = "15m";
        REFRESH_TOKEN_EXPIRES_IN = "30d";
        # Banner in de Android-app als er een nieuwe APK-release is.
        APP_UPDATE_REPO = "Marukiee/MarkMySteps";
      };
      environmentFiles = [ config.age.secrets.markmysteps-env.path ];
      # De web-container proxyt /api/ naar http://api:3000.
      extraOptions = [ "--network=${netName}" "--network-alias=api" ];
    };

    markmysteps-web = {
      image = webImage;
      pull = "never";
      autoStart = true;
      dependsOn = [ "markmysteps-api" ];
      # Loopback: Docker-poorten omzeilen de NixOS-firewall. In de container altijd 80.
      ports = [ "127.0.0.1:8091:80" ];
      extraOptions = [ "--network=${netName}" ];
    };
  };

  services.nginx.virtualHosts."markmysteps.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";

    locations."/" = {
      proxyPass = "http://127.0.0.1:8091";
      extraConfig = ''
        # Polarsteps-zip tot 100 MB, plus video's.
        client_max_body_size 200M;
        client_body_timeout 600s;
      '';
    };
  };
}
