{ config, pkgs, ... }:
{
  virtualisation.docker.enable = true;

  networking.firewall.allowedUDPPorts = [ 51820 ];
  networking.firewall.allowedTCPPorts = [ 51821 ]; # wg-easy web UI

  # NAT zodat client's internet via server gaat
  networking.nat = {
    enable = true;
    externalInterface = "eth0";   # aanpassen aan jouw interface
    internalInterfaces = [ "wg0" ];
  };

  # wg-easy container
  virtualisation.oci-containers.containers."wg-easy" = {
    image = "ghcr.io/wg-easy/wg-easy:latest";
    autoStart = true;

    environment = {
      WG_HOST = "wg.toorren.net";
      PASSWORD_HASH = "$argon2id$v=19$m=65540,t=3,p=4$ZGVoZWVyaXNtaWpuaGVyZGVy$3kx+J19Ce0zEt5fgA1bwbevgcMrgW2x08bjk3u54e4o"; 
      WG_PORT = "51820";
      WG_DEFAULT_DNS = "1.1.1.1";
      WG_DEFAULT_ADDRESS = "10.8.0.x";
      WG_ALLOWED_IPS = "0.0.0.0/0,::/0"; # full tunnel
    };

    # Volumes voor persistent config
    volumes = [
      "/var/lib/wg-easy:/etc/wireguard"
    ];

    ports = [
      "51820:51820/udp"
      "51821:51821/tcp"
    ];

    extraOptions = [
      "--cap-add=NET_ADMIN"
      "--cap-add=SYS_MODULE"
      "--sysctl=net.ipv4.ip_forward=1"
      "--sysctl=net.ipv4.conf.all.src_valid_mark=1"
    ];
  };

  services.nginx.virtualHosts."wg.toorren.net" = {
    enableACME = true;
    forceSSL = true;
    locations = {
      "/" = {
        proxyPass = "http://192.168.2.52:51821";
      };
    };
  };
}

