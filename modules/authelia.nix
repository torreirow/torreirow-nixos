{ config, pkgs, ... }:

{
  age.secrets = {
    authelia-jwt = {
      file = ../secrets/authelia-jwt.age;
      owner = "authelia";
      mode = "0400";
    };

    authelia-session = {
      file = ../secrets/authelia-session.age;
      owner = "authelia";
      mode = "0400";
    };

    authelia-storage = {
      file = ../secrets/authelia-storage.age;
      owner = "authelia";
      mode = "0400";
    };

    authelia-users = {
      file = ../secrets/authelia-users.age;
      owner = "authelia";
      mode = "0400";
    };
  };

  services.authelia = {
    enable = true;

    settings = {
      theme = "dark";

      server.address = "tcp://127.0.0.1:9091";

      log.level = "info";

      jwt_secret = config.age.secrets.authelia-jwt.path;

      authentication_backend.file = {
        path = config.age.secrets.authelia-users.path;
        password.algorithm = "argon2id";
      };

      access_control = {
        default_policy = "deny";
        rules = [
          {
            domain = "*.jouwdomein.nl";
            policy = "one_factor";
          }
        ];
      };

      session = {
        name = "authelia_session";
        secret = config.age.secrets.authelia-session.path;
        expiration = "1h";
        inactivity = "15m";
        domain = "jouwdomein.nl";
      };

      storage = {
        encryption_key = config.age.secrets.authelia-storage.path;
        local.path = "/var/lib/authelia/db.sqlite3";
      };

      notifier.filesystem.filename = "/var/lib/authelia/notification.txt";
    };
  };

  users.users.authelia.extraGroups = [ "nginx" ];
}

