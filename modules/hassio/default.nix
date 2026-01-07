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
        "--device=/dev/ttyUSB0:/dev/ttyUSB0"
        "--device=/dev/serial/by-id/usb-FTDI_FT232R_USB_UART_AQ78GLG6-if00-port0:/dev/serial/by-id/usb-FTDI_FT232R_USB_UART_AQ78GLG6-if00-port0"
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
