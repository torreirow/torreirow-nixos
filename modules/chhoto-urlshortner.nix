{ config, pkgs, agenix,... }:

{
  # Expliciete user/group voor chhoto-url
  # (in plaats van DynamicUser, zodat agenix kan chownen tijdens activatie)
  users.users.chhoto-url = {
    isSystemUser = true;
    group = "chhoto-url";
    description = "Chhoto URL shortener service user";
  };

  users.groups.chhoto-url = {};

  # Agenix configuratie voor credentials
  age.secrets.chhoto-url-database = {
    file = ../secrets/chhoto-url-database.age;
    path = "/run/agenix/chhoto-url-database";
    owner = "chhoto-url";
    group = "chhoto-url";
    mode = "0400";
  };

  age.secrets.chhoto-url-api-key = {
    file = ../secrets/chhoto-url-api-key.age;
    path = "/run/agenix/chhoto-url-api-key";
    owner = "chhoto-url";
    group = "chhoto-url";
    mode = "0400";
  };

  age.secrets.chhoto-url-adminpwd = {
    file = ../secrets/chhoto-url-adminpwd.age;
    path = "/run/agenix/chhoto-url-adminpwd";
    owner = "chhoto-url";
    group = "chhoto-url";
    mode = "0400";
  };

   age.secrets.chhoto-url-env = {
    file = ../secrets/chhoto-url-env.age;
    path = "/run/agenix/chhoto-url-env";
    owner = "chhoto-url";
    group = "chhoto-url";
    mode = "0400";
 };

  # Chhoto-url service configuratie
  services.chhoto-url = {
    enable = true;

    # Niet publiek
    settings = {
      public_mode = false;
      port = 4567;
      site_url = "https://url.toorren.net";
      slug_length = 8;
      try_longer_slugs = true;
    };

    # Admin password via age secret
    environmentFiles = [
      config.age.secrets.chhoto-url-env.path
    ];
  };

  # Override systemd service om DynamicUser uit te schakelen
  # en onze expliciete user/group te gebruiken
  systemd.services.chhoto-url = {
    serviceConfig = {
      DynamicUser = pkgs.lib.mkForce false;
      User = "chhoto-url";
      Group = "chhoto-url";
    };
  };

  # Nginx reverse proxy
  services.nginx = {
    virtualHosts."url.toorren.net" = {
      forceSSL = true;
      useACMEHost = "toorren.net";
      locations."/" = {
        proxyPass = "http://127.0.0.1:4567";
        proxyWebsockets = true;
      };
    };
  };
}
