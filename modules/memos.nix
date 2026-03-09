{ config, pkgs, ... }:

{

  age.secrets.memos-psql = {
    file = ../secrets/memos-psql.age;
    path = "/run/agenix/memos-psql";
  };


  # Memos service met PostgreSQL
  services.memos = {
    enable = true;
    settings = {
    MEMOS_MODE = "prod";
    MEMOS_ADDR = "127.0.0.1";
    MEMOS_PORT = "8087";
    MEMOS_DATA = "/var/lib/memos";
    MEMOS_DRIVER = "postgres";
    MEMOS_DSN="postgresql://memos:Negation2-Luxurious-Dilute@localhost:5432/memos?sslmode=disable";
    MEMOS_INSTANCE_URL = "https://memos.toorren.net";
  };
  };

  # Nginx reverse proxy
  services.nginx = {
  enable = true;
  recommendedProxySettings = true;
  virtualHosts."memos.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";

    # Specifieke route voor Moe Memos compatibility
    locations."/api/v1/status" = {
      extraConfig = ''
        return 200 '{"status":"ok"}';
        add_header Content-Type application/json;
      '';
    };

    # Hoofdroute
    locations."/" = {
      proxyPass = "http://127.0.0.1:8087";
      proxyWebsockets = true;
      extraConfig = ''
        client_max_body_size 100M;
      '';
    };
  };
};

}
