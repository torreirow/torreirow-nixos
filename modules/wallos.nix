{ config, pkgs, lib, ... }:

{
  age.secrets.wallos-env = {
    file = ../secrets/wallos-env.age;
    path = "/run/agenix/wallos-env";
    mode = "0400";
  };

  # Wallos - Self-hosted subscription tracker
  virtualisation.oci-containers.containers.wallos = {
    image = "bellamy/wallos:latest";
    environment = {
      TZ = "Europe/Amsterdam";
      # OIDC login via Authelia (geen eigen login)
      OIDC_ENABLED = "true";
      OIDC_PROVIDER_NAME = "Authelia";
      OIDC_CLIENT_ID = "wallos";
      OIDC_ISSUER = "https://auth.toorren.net";
      OIDC_AUTH_URL = "https://auth.toorren.net/api/oidc/authorization";
      OIDC_TOKEN_URL = "https://auth.toorren.net/api/oidc/token";
      OIDC_USERINFO_URL = "https://auth.toorren.net/api/oidc/userinfo";
      OIDC_REDIRECT_URL = "https://subscriptions.toorren.net/index.php";
      OIDC_LOGOUT_URL = "https://auth.toorren.net/logout";
      OIDC_SCOPES = "openid email profile";
      OIDC_USER_IDENTIFIER = "sub";
      OIDC_DISABLE_PASSWORD_LOGIN = "true";
      OIDC_AUTO_CREATE_USER = "true";
      SSRF_ALLOWLIST = "host.docker.internal";
    };
    volumes = [
      "/data/external/wallos/db:/var/www/html/db"
      "/data/external/wallos/logos:/var/www/html/images/uploads/logos"
      "/data/external/wallos/nginx-default.conf:/etc/nginx/http.d/default.conf:ro"
    ];
    ports = [
      "127.0.0.1:8095:80"
    ];
    extraOptions = [
      "--add-host=host.docker.internal:host-gateway"
      "--env-file=${config.age.secrets.wallos-env.path}"
    ];
  };

  # MariaDB: wallos database en gebruiker
  services.mysql.ensureDatabases = lib.mkAfter [ "wallos" ];
  services.mysql.ensureUsers = lib.mkAfter [
    {
      name = "wallos";
      ensurePermissions = {
        "wallos.*" = "ALL PRIVILEGES";
      };
    }
  ];

  # Data directories (www-data in container is UID/GID 82 in Alpine)
  systemd.tmpfiles.rules = [
    "d /data/external/wallos 0755 root root -"
    "d /data/external/wallos/db 0775 82 82 -"
    "d /data/external/wallos/logos 0775 82 82 -"
  ];

  # Nginx reverse proxy - geen forward-auth (Wallos regelt login via OIDC)
  services.nginx.virtualHosts."subscriptions.toorren.net" = {
    useACMEHost = "toorren.net";
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8095";
      proxyWebsockets = true;
      extraConfig = ''
        client_max_body_size 10M;
      '';
    };
  };
}
