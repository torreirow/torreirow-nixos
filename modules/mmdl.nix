{ config, pkgs, ... }:

{
  age.secrets.mmdl-env = {
    file = ../secrets/mmdl-env.age;
    path = "/run/agenix/mmdl-env";
    mode = "0400";
  };

  virtualisation.oci-containers.containers.mmdl = {
    image = "intriin/mmdl:latest";
    autoStart = true;
    ports = [
      "127.0.0.1:8091:3000"
    ];
    volumes = [
      "/var/lib/mmdl:/app/data"
    ];
    environment = {
      NEXT_BASE_URL = "https://mmdl.toorren.net/";
      NEXT_PUBLIC_API_URL = "https://mmdl.toorren.net/api";
      DB_DIALECT = "sqlite";
      DB_NAME = "/app/data/mmdl.db";
      DOCKER_INSTALL = "true";
      DISABLE_USER_REGISTRATION = "false";
      ADDITIONAL_VALID_CALDAV_URL_LIST = ''["https://adresses.toorren.net"]'';
      MAX_CONCURRENT_LOGINS_ALLOWED = "3";
      MAX_OTP_VALIDITY = "1800";
      MAX_SESSION_LENGTH = "2592000";
      ENFORCE_SESSION_TIMEOUT = "true";
    };
    extraOptions = [
      "--env-file=${config.age.secrets.mmdl-env.path}"
    ];
  };

  # nextjs user in container draait als UID/GID 1001
  systemd.tmpfiles.rules = [
    "d /var/lib/mmdl 0755 1001 1001 -"
  ];

  services.nginx.virtualHosts."mmdl.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";

    locations."/" = {
      proxyPass = "http://127.0.0.1:8091";
      proxyWebsockets = true;
      extraConfig = ''
        auth_request /authelia;
        error_page 401 = @authelia_portal;

        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };

    locations."@authelia_portal" = {
      extraConfig = ''
        return 302 https://auth.toorren.net/?rd=$scheme://$http_host$request_uri;
      '';
    };

    locations."/authelia" = {
      proxyPass = "http://127.0.0.1:9091/api/verify";
      extraConfig = ''
        internal;
        proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header Content-Length "";
        proxy_pass_request_body off;
      '';
    };
  };
}
