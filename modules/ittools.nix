{ config, pkgs, ... }:

{
  # Enable OCI container support (compatible with Docker)
  virtualisation.oci-containers = {
    backend = "docker"; # or "podman" if you prefer
    
    containers = {
      it-tools = {
        # Eigen build van de fork torreirow/it-tools (gebaseerd op sharevb/it-tools),
        # gebouwd door GitHub Actions. Uitrollen van een nieuwe build:
        #   systemctl restart docker-it-tools   (pull = "always" haalt dan :latest op)
        image = "ghcr.io/torreirow/it-tools:latest";
        pull = "always";

        # Port mapping: host:container. Alleen loopback: Docker-poorten omzeilen de
        # NixOS-firewall, en it-tools hoort alleen via nginx + Authelia bereikbaar te zijn.
        # Het sharevb-image draait nginx-unprivileged en luistert op 8080.
        ports = [
          "127.0.0.1:8085:8080"
        ];
        
        # Optional: Add labels for better organization
        labels = {
          "app" = "it-tools";
          "description" = "IT-Tools - Handy tools for developers";
        };
        
         environment = {
           TZ = "Europe/Amsterdam";
         };
        
      };
    };
  };

  services.nginx.virtualHosts."ittools.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";

    # Geen JS-herschrijving of font-proxy naar een CDN meer: het sharevb-image levert
    # zijn ASCII-art-fonts zelf, en de COOP/COEP-headers van het image gaan ongewijzigd door.
    locations."/" = {
      proxyPass = "http://127.0.0.1:8085";
      proxyWebsockets = false;
      extraConfig = ''
        auth_request /authelia;
        error_page 401 = @authelia_portal;

        proxy_http_version 1.1;
        proxy_set_header Connection "";

        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };

  # Authelia redirect named location
  locations."@authelia_portal" = {
    extraConfig = ''
        return 302 https://auth.toorren.net/?rd=$scheme://$http_host$request_uri;
    '';
  };

    # Authelia authentication endpoint
    locations."/authelia" = {
      proxyPass = "http://127.0.0.1:9091/api/verify";
      extraConfig = ''
        internal;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header Content-Length "";
        proxy_pass_request_body off;
      '';
    };
  };

  
}
