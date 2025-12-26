{ config, pkgs, ... }:

{
  virtualisation.docker.enable = true;

  # Firewall
  networking.firewall = {
    enable = true;
    allowedUDPPorts = [ 51820 ];
    allowedTCPPorts = [ 51821 ];
    checkReversePath = "loose";
    trustedInterfaces = [ "docker0" ];
  };

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # NAT voor Docker bridge
  networking.nat = {
    enable = true;
    externalInterface = "enp3s0";
    internalInterfaces = [ "docker0" ];
  };

  # wg-easy DOCKER container (GEEN host networking)
  virtualisation.oci-containers = {
    backend = "docker";
    containers.wg-easy = {
      image = "ghcr.io/wg-easy/wg-easy:latest";
      ports = [
        "51820:51820/udp"
        "51821:51821/tcp"
      ];
      volumes = [ "/var/lib/wg-easy:/etc/wireguard" ];
      environment = {
        WG_HOST = "wg.toorren.net";
        PASSWORD_HASH = "$2a$12$2kO66Q7Xg4JI/n2QzXW9ROTZ0O2yJA/NJCuYMDl.YU9g8PS.ZYJsi";
        WG_DEFAULT_DNS = "1.1.1.1";
        WG_ALLOWED_IPS = "0.0.0.0/0";  # Belangrijk voor Android full tunnel
      };
      capabilities = {
        NET_ADMIN = true;
        SYS_MODULE = true;
      };
      autoStart = true;
    };
  };

  services.nginx.enable = true;
  services.nginx.virtualHosts."wg.toorren.net" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:51821";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}

