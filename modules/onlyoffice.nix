{ config, pkgs, lib, ... }:

{
  # Docker voor OnlyOffice
  virtualisation.docker.enable = true;

  # Nginx en SSL
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    virtualHosts."docspace.toorren.net" = {
      enableACME = true;
      forceSSL = true;
      
      locations."/" = {
        proxyPass = "http://127.0.0.1:8080";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
          
          client_max_body_size 100M;
          
          proxy_connect_timeout 600;
          proxy_send_timeout 600;
          proxy_read_timeout 600;
          send_timeout 600;
        '';
      };
    };
  };

  systemd.services.onlyoffice-docspace = {
    description = "OnlyOffice DocSpace";
    after = [ "docker.service" "network.target" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    
    path = [ pkgs.docker pkgs.docker-compose pkgs.curl pkgs.bash ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = "/var/lib/onlyoffice";
      ExecStartPre = pkgs.writeShellScript "setup-docspace" ''
        mkdir -p /var/lib/onlyoffice
        cd /var/lib/onlyoffice
        
        # Download de officiële docker-compose.yml als die nog niet bestaat
        if [ ! -f docker-compose.yml ]; then
          ${pkgs.curl}/bin/curl -fsSL https://download.onlyoffice.com/docspace/docspace-compose.yml -o docker-compose.yml
        fi
      '';
      ExecStart = "${pkgs.docker-compose}/bin/docker-compose up -d";
      ExecStop = "${pkgs.docker-compose}/bin/docker-compose down";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  # Directories aanmaken
  systemd.tmpfiles.rules = [
    "d /var/lib/onlyoffice 0755 root root -"
  ];

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 ];
  };
}
