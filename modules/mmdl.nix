{ config, pkgs, ... }:

{
  age.secrets.mmdl-env = {
    file = ../secrets/mmdl-env.age;
    path = "/run/secrets/mmdl-env";
    mode = "0400";
  };

  virtualisation.oci-containers.containers.mmdl = {
    image = "intriin/mmdl:latest";
    autoStart = true;
    ports = [
      "127.0.0.1:3000:3000"
    ];
    volumes = [
      "/var/lib/mmdl:/app/data"
    ];
    environment = {
      NEXT_BASE_URL = "http://localhost:3000/";
      NEXT_PUBLIC_API_URL = "http://localhost:3000/api";
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
}
