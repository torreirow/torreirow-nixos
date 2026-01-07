{ config, pkgs, ... }:

{
  virtualisation.oci-containers = {
    backend = "docker";

    containers.vaultwarden = {
      image = "vaultwarden/server:latest";
      environment = {
        DOMAIN = "https://vw.toorren.net";
        ROCKET_PORT = "8080"; 
        TZ = "Europe/Amsterdam";
      };
      volumes = [
        "/var/lib/vaultwarden:/data"
      ];
      extraOptions = [
        "--network=host"
      ];
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 8080 ];
  };

  services.nginx.virtualHosts."vw.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";
    locations = {
      "/" = {
        proxyPass = "http://127.0.0.1:8080";
        proxyWebsockets = true;
      };
    };
  };

}
