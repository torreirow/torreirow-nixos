{ config, pkgs, lib, agenix, ... }:

{

  age.secrets.postfix-sasl-password = {
    file = ./secrets/gitea-admin.age;
  };

  servive.gitea = {
    enable = true;
    stateDir = "/var/lib/gitea";
    siteKey = "toorrenaer";
    captcha.enable = false;
    settings = {
      "cron.sync_external_users" = {
        RUN_AT_START = true;
        SCHEDULE = "@every 24h";
        UPDATE_EXISTING = true;
      };
      #mailer = {
      #  ENABLED = true;
      #  PROTOCOL = "smtp+starttls";
      #  SMTP_ADDR = "smtp.example.org";
      #  SMTP_PORT = "587";
      #  FROM = "Gitea Service <do-not-reply@example.org>";
      #  USER = "do-not-reply@example.org";
      #};
      other = {
        SHOW_FOOTER_VERSION = false;
      };
    };
    settings.server.DOMAIN = "git.toorren.net";
    database.user = "gitea";
    database.type = "postgres";
    database.paassword = config.age.secrets.gitea-admin.path;

  };
}

