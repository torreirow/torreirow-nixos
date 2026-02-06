{ config, pkgs, agenix,... }:

{
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

  # PostgreSQL database configuratie
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "chhoto_url" ];
    ensureUsers = [
      {
        name = "chhoto_url";
        ensureDBOwnership = true;
      }
    ];
  };

  # Chhoto-url service configuratie
  services.chhoto-url = {
    enable = true;
    
    port = 4567;
    
    siteUrl = "https://url.toorren.net";
    
    # PostgreSQL database connection string via age file
    databaseFile = config.age.secrets.chhoto-url-database.path;
    
    # API key voor authenticatie
    apiKeyFile = config.age.secrets.chhoto-url-api-key.path;
    
    # Slug configuratie
    slugStyle = "petname";
    slugLength = 8;
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
