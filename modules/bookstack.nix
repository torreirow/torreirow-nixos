{ config, lib, ... }:

{
  # bookstack-setup.service heeft PrivateUsers=yes wat UID remapping veroorzaakt,
  # waardoor het de agenix secrets (owned by bookstack) niet kan lezen.
  systemd.services.bookstack-setup.serviceConfig.PrivateUsers = lib.mkForce false;

  # bookstack user moet in de 'keys' group zitten om /run/keys/ te kunnen betreden
  # (agenix secrets staan daar, directory heeft mode 750 group=keys)
  users.users.bookstack.extraGroups = [ "keys" ];
  age.secrets.bookstack-appkey = {
    file = ../secrets/bookstack-appkey.age;
    owner = "bookstack";
    mode = "0400";
  };

  age.secrets.bookstack-db-password = {
    file = ../secrets/bookstack-db-password.age;
    owner = "bookstack";
    mode = "0400";
  };

  services.bookstack = {
    enable = true;
    hostname = "stwvwiki.toorren.net";

    nginx = {
      forceSSL = true;
      useACMEHost = "toorren.net";
    };

    settings = {
      APP_KEY_FILE = config.age.secrets.bookstack-appkey.path;

      DB_HOST = "localhost";
      DB_DATABASE = "bookstack";
      DB_USERNAME = "bookstack";
      DB_PASSWORD_FILE = config.age.secrets.bookstack-db-password.path;

      MAIL_DRIVER = "smtp";
      MAIL_HOST = "localhost";
      MAIL_PORT = 25;
      MAIL_FROM = "bookstack@toorren.net";
      MAIL_FROM_NAME = "BookStack";

      # Sta openbare toegang toe (gasten kunnen content zien als rechten dat toestaan)
      APP_PUBLIC = "true";
    };
  };
}
