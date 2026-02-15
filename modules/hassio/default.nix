{ config, pkgs, ... }:

{
  # Create stable /dev/zigbee symlink for Sonoff Zigbee USB dongle
  services.udev.extraRules = ''
    SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", ATTRS{serial}=="0001", SYMLINK+="zigbee"
  '';

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
        "--volume=/run/dbus:/run/dbus:ro"
      ];
    };

    containers.zigbee2mqtt = {
      image = "koenkk/zigbee2mqtt:latest";
      environment = {
        TZ = "Europe/Amsterdam";
      };
      volumes = [
        "/var/lib/zigbee2mqtt:/app/data"
        "/run/udev:/run/udev:ro"
      ];
      extraOptions = [
        "--network=host"
        "--device=/dev/zigbee:/dev/zigbee"
        "--group-add=27"
      ];
    };
  };

  # Create zigbee2mqtt directories
  systemd.tmpfiles.rules = [
    "d /var/lib/zigbee2mqtt 0755 root root -"
  ];

  # Create zigbee2mqtt config file
  environment.etc."zigbee2mqtt/configuration.yaml" = {
    text = ''
      homeassistant: true
      permit_join: false
      mqtt:
        base_topic: zigbee2mqtt
        server: mqtt://127.0.0.1:1883
      serial:
        port: /dev/zigbee
        adapter: zstack
      frontend:
        enabled: true
        port: 8086
      advanced:
        log_level: info
        network_key: GENERATE
        pan_id: GENERATE
        ext_pan_id: GENERATE
    '';
  };

  # Copy config to the right location
  system.activationScripts.zigbee2mqttConfig = ''
    mkdir -p /var/lib/zigbee2mqtt
    if [ ! -f /var/lib/zigbee2mqtt/configuration.yaml ]; then
      cp /etc/zigbee2mqtt/configuration.yaml /var/lib/zigbee2mqtt/configuration.yaml
    fi
  '';

  networking.firewall = {
    allowedTCPPorts = [ 8123 8086 ];
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

  services.nginx.virtualHosts."zigbee2mqtt.toorren.net" = {
    useACMEHost = "toorren.net";
    forceSSL = true;
    locations = {
      "/" = {
        proxyPass = "http://127.0.0.1:8086";
        proxyWebsockets = true;
        extraConfig = ''
          auth_request /authelia;
          error_page 401 = @authelia_portal;

          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };

      "@authelia_portal" = {
        extraConfig = ''
          return 302 https://auth.toorren.net/?rd=$scheme://$http_host$request_uri;
        '';
      };

      "/authelia" = {
        proxyPass = "http://127.0.0.1:9091/api/verify";
        extraConfig = ''
          internal;
          proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
          proxy_set_header X-Forwarded-For $remote_addr;
          proxy_set_header Content-Length "";
          proxy_pass_request_body off;
        '';
      };
    };
  };
}
