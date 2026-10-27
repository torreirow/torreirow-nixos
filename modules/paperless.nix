{ config, pkgs, lib, agenix, ... }:

# Paperless-ngx (docs.toorren.net) als NixOS oci-containers, i.p.v. de handmatige docker compose-stack
# in ${baseDir}. Aanleiding: na de reboot van 2026-10-17 kon de compose-broker niet starten (het netwerk-ID
# waar hij naar verwees bestond niet meer) en Docker herstartte hem nooit; de webserver zat 10 dagen in een
# herstart-lus (10.552×). Nu maakt init-paperless-net het netwerk bij elke boot aan vóór de containers.
#
#   paperless-broker     redis:8, named volume paperless_redisdata (zelfde volume als onder compose)
#   paperless-webserver  127.0.0.1:8181 → 8000; nginx + Authelia ervoor (Remote-User-header)
#
# Postgres draait op de host (modules/postgres.nix: pg_hba `host paperless paperless 172.18.0.0/16`),
# bereikbaar via de gateway 172.18.0.1. Daarom heeft het netwerk een vast subnet.
# Zie docs/paperless.md.

let
  baseDir = "/data/external/tmp/paperless/paperless-ngx";
  netName = "paperless";
  subnet = "172.18.0.0/16";
  gateway = "172.18.0.1";
in
{
  # Inhoud: PAPERLESS_SECRET_KEY=… en PAPERLESS_DBPASS=… (zonder aanhalingstekens: docker --env-file
  # neemt die letterlijk over, compose stripte ze).
  age.secrets.paperless-env = {
    file = ../secrets/paperless-env.age;
    mode = "0400";
  };

  virtualisation.docker.enable = true;

  systemd.tmpfiles.rules = [
    # Data-map (index, classificatiemodel, celerybeat) — onder compose een anoniem docker-volume,
    # nu een bind mount zodat hij ook in de rustic-backup van /data/external/tmp/paperless zit.
    "d ${baseDir}/data 0755 wtoorren users - -"
  ];

  systemd.services.init-paperless-net = {
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

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      paperless-broker = {
        image = "docker.io/library/redis:8";
        volumes = [ "paperless_redisdata:/data" ];
        extraOptions = [ "--network=${netName}" ];
        autoStart = true;
      };

      paperless-webserver = {
        image = "ghcr.io/paperless-ngx/paperless-ngx:latest";
        # Alleen loopback: Paperless vertrouwt de Remote-User-header, dus hij mag niet direct
        # bereikbaar zijn (onder compose stond hij op 0.0.0.0:8181).
        ports = [ "127.0.0.1:8181:8000" ];
        volumes = [
          "${baseDir}/consume:/usr/src/paperless/consume"
          "${baseDir}/media:/usr/src/paperless/media"
          "${baseDir}/export:/usr/src/paperless/export"
          "${baseDir}/data:/usr/src/paperless/data"
        ];
        environment = {
          PAPERLESS_URL = "https://docs.toorren.net";
          PAPERLESS_REDIS = "redis://paperless-broker:6379";
          PAPERLESS_DBENGINE = "postgresql";
          PAPERLESS_DBHOST = gateway;
          PAPERLESS_DBPORT = "5432";
          PAPERLESS_DBNAME = "paperless";
          PAPERLESS_DBUSER = "paperless";
          PAPERLESS_TIME_ZONE = "Europe/Amsterdam";
          PAPERLESS_OCR_LANGUAGE = "nld";
          PAPERLESS_OCR_LANGUAGES = "nld";
          PAPERLESS_ENABLE_HTTP_REMOTE_USER = "true";
          PAPERLESS_HTTP_REMOTE_USER_HEADER = "Remote-User";
          USERMAP_GID = "100";
        };
        extraOptions = [
          "--network=${netName}"
          "--add-host=host.docker.internal:host-gateway"
          "--env-file=${config.age.secrets.paperless-env.path}"
        ];
        dependsOn = [ "paperless-broker" ];
        autoStart = true;
      };
    };
  };

  systemd.services.docker-paperless-broker = {
    after = [ "init-paperless-net.service" ];
    requires = [ "init-paperless-net.service" ];
  };
  systemd.services.docker-paperless-webserver = {
    after = [ "init-paperless-net.service" "postgresql.service" ];
    requires = [ "init-paperless-net.service" ];
  };

  services.nginx.virtualHosts."docs.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";
    locations."/" = {
      proxyPass = "http://127.0.0.1:8181";
      proxyWebsockets = false;
      extraConfig = ''
        auth_request /authelia;
        error_page 401 = @authelia_portal;

        auth_request_set $user $upstream_http_remote_user;
        auth_request_set $groups $upstream_http_remote_groups;
        auth_request_set $name $upstream_http_remote_name;
        auth_request_set $email $upstream_http_remote_email;
        proxy_set_header Remote-User $user;
        proxy_set_header Remote-Groups $groups;
        proxy_set_header Remote-Name $name;
        proxy_set_header Remote-Email $email;

        proxy_http_version 1.1;
        proxy_set_header Connection "";

        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  # Authelia redirect named location
  locations."@authelia_portal" = {
    extraConfig = ''
        return 302 https://auth.toorren.net/?rd=$scheme://$http_host$request_uri;
    '';
  };

    # Authelia authentication endpoint
    locations."/authelia" = {
      proxyPass = "http://127.0.0.1:9091/api/verify";
      extraConfig = ''
        internal;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header Content-Length "";
        proxy_pass_request_body off;
      '';
    };
  };

#  networking.firewall.interfaces.docker0.allowedTCPPorts = [ 5432 ];
}
