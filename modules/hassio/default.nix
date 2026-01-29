{ config, pkgs, ... }:

{
  virtualisation.oci-containers = {
    backend = "docker";

    containers.homeassistant = {
      image = "ghcr.io/home-assistant/home-assistant:stable";
      environment.TZ = "Europe/Amsterdam";
      volumes = [
        "/var/lib/homeassistant:/config"
      ];
      extraOptions = [
        "--network=host"
        "--privileged"
        "--volume=/dev/serial/by-id:/dev/serial/by-id:rw"
        "--volume=/run/dbus:/run/dbus:ro"
      ];
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 8123 ];
  };

  services.nginx.virtualHosts."homeassistant.toorren.net" = {
    useACMEHost = "toorren.net";
    forceSSL = true;
    locations = {
      "/" = {
        proxyPass = "http://127.0.0.1:8123";
        proxyWebsockets = true;
      };
    };
  };


}
