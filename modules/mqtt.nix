{ config, pkgs, ... }:

{
  virtualisation.oci-containers = {
    backend = "docker";

    containers.mosquitto = {
      image = "eclipse-mosquitto:latest";
      environment.TZ = "Europe/Amsterdam";
      volumes = [
        "/var/lib/mosquitto:/mosquitto"
      ];
      ports = [
        "1883:1883"
        "9001:9001"
      ];
    };
  };

  # Create mosquitto directories and config
  systemd.tmpfiles.rules = [
    "d /var/lib/mosquitto 0755 root root -"
    "d /var/lib/mosquitto/config 0755 root root -"
    "d /var/lib/mosquitto/data 0755 root root -"
    "d /var/lib/mosquitto/log 0755 root root -"
  ];

  # Create mosquitto config file
  environment.etc."mosquitto/mosquitto.conf" = {
    text = ''
      listener 1883
      allow_anonymous true
      persistence true
      persistence_location /mosquitto/data/
      log_dest file /mosquitto/log/mosquitto.log
    '';
  };

  # Copy config to the right location
  system.activationScripts.mosquittoConfig = ''
    mkdir -p /var/lib/mosquitto/config
    cp /etc/mosquitto/mosquitto.conf /var/lib/mosquitto/config/mosquitto.conf
  '';

  networking.firewall = {
    allowedTCPPorts = [ 1883 9001 ];
  };
}
