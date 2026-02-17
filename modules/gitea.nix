{ config, pkgs, lib, agenix, ... }:

{

  age.secrets.gitea-admin = {
    file = ../secrets/gitea-admin.age;
  };

  services.gitea = {
    enable = true;
    stateDir = "/var/lib/gitea";

      #  PROTOCOL = "smtp+starttls";
      #  SMTP_ADDR = "smtp.example.org";
      #  SMTP_PORT = "587";
      #  FROM = "Gitea Service <do-not-reply@example.org>";
      #  USER = "do-not-reply@example.org";
      #};
    settings.server.DOMAIN = "git.toorren.net";
    database.user = "gitea";
    database.type = "postgres";
    #database.password = config.age.secrets.gitea-admin.path;
    database.passwordFile = config.age.secrets.gitea-admin.path;

    captcha = {
      siteKey = "toorrenaer";
      enable = false;
    };
  };
}

