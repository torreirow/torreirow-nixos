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
        # Bluetooth permissions for full hardware access
        "--cap-add=NET_ADMIN"
        "--cap-add=NET_RAW"
        # DSMR P1 Smart Meter (FTDI USB serial)
        "--device=/dev/ttyUSB0:/dev/ttyUSB0"
      ];
    };

    containers.zigbee2mqtt = {
      image = "koenkk/zigbee2mqtt:latest";
      environment = {
        TZ = "Europe/Amsterdam";
        # Voorkom OOM crash: beperk Node.js heap tot 512 MB
        NODE_OPTIONS = "--max-old-space-size=512";
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

  # Create Home Assistant template files
  environment.etc."homeassistant/templates/stookwijzer.yaml" = {
    source = ./templates/stookwijzer.yaml;
  };


  # Reset Zigbee USB coordinator voor Z2M start — voorkomt SRSP-SYS ping timeout na crash
  systemd.services.zigbee-usb-reset = {
    description = "Reset Zigbee USB coordinator";
    before = [ "docker-zigbee2mqtt.service" ];
    wantedBy = [ "docker-zigbee2mqtt.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "zigbee-usb-reset" ''
        USB_PATH=$(find /sys/bus/usb/devices -name idVendor -exec grep -l "10c4" {} \; | head -1 | xargs dirname | xargs basename 2>/dev/null || echo "")
        if [ -n "$USB_PATH" ]; then
          echo "$USB_PATH" > /sys/bus/usb/drivers/usb/unbind || true
          sleep 2
          echo "$USB_PATH" > /sys/bus/usb/drivers/usb/bind || true
        fi
      '';
    };
  };

  # Copy config to the right location
  system.activationScripts.zigbee2mqttConfig = ''
    mkdir -p /var/lib/zigbee2mqtt
    if [ ! -f /var/lib/zigbee2mqtt/configuration.yaml ]; then
      cp /etc/zigbee2mqtt/configuration.yaml /var/lib/zigbee2mqtt/configuration.yaml
    fi
  '';

  # Copy Home Assistant templates
  system.activationScripts.homeassistantTemplates = ''
    mkdir -p /var/lib/homeassistant/templates
    cp /etc/homeassistant/templates/stookwijzer.yaml /var/lib/homeassistant/templates/stookwijzer.yaml
    chown -R root:root /var/lib/homeassistant/templates
    chmod -R 644 /var/lib/homeassistant/templates/*.yaml
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
