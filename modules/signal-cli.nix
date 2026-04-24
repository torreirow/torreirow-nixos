{ config, pkgs, ... }:

{
  # Signal CLI REST API container for Home Assistant notifications
  virtualisation.oci-containers.containers.signal-cli = {
    image = "bbernhard/signal-cli-rest-api:latest";
    environment = {
      MODE = "native";
      TZ = "Europe/Amsterdam";
    };
    volumes = [
      "/var/lib/signal-cli:/home/.local/share/signal-cli"
    ];
    ports = [
      "127.0.0.1:8088:8080"  # Map internal 8080 to external 8088 (localhost only)
    ];
  };

  # Create signal-cli data directory
  systemd.tmpfiles.rules = [
    "d /var/lib/signal-cli 0755 root root -"
  ];

  # Open firewall for Signal CLI API (local only)
  networking.firewall.allowedTCPPorts = [ 8088 ];
}
