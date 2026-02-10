{ config, pkgs, ... }:

{

  age.secrets.memos-psql = {
    file = ../secrets/memos.psql.age;
    path = "/run/agenix/memos-psql";
  };


  # Memos service met PostgreSQL
  services.memos = {
    enable = true;
    port = 8087;  # Jouw gewenste poort
  };

  # PostgreSQL connection string voor Memos
  systemd.services.memos.serviceConfig = {
    EnvironmentFile = config.age.secrets.memos-psql.path;
  };

  # Nginx reverse proxy
  services.nginx = {
    enable = true;
    
    virtualHosts."memos.toorren.net" = {
      forceSSL = true;
      useACMEHost = "toorren.net";
      
      locations."/" = {
        proxyPass = "http://127.0.0.1:8087";
        proxyWebsockets = true;
        
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          
          # WebSocket support
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
          
          # Timeouts
          proxy_connect_timeout 60s;
          proxy_send_timeout 60s;
          proxy_read_timeout 60s;
          
          client_max_body_size 100M;
        '';
      };
    };
  };

}
