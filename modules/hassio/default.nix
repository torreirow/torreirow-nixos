{ config, pkgs, ... }:

{
  # Create stable symlinks for USB serial adapters
  services.udev.extraRules = ''
    SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", ATTRS{serial}=="0001", SYMLINK+="zigbee"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="AQ78GLG6", SYMLINK+="dsmr"
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
        # DSMR P1 Smart Meter (FTDI USB serial, stable symlink)
        "--device=/dev/dsmr:/dev/dsmr"
      ];
    };

    containers.zigbee2mqtt = {
      image = "koenkk/zigbee2mqtt:latest";
      environment = {
        TZ = "Europe/Amsterdam";
        # Voorkom OOM crash: beperk Node.js heap tot 512 MB
        NODE_OPTIONS = "--max-old-space-size=512";
        # Schakel fout-pagina op poort 8080 uit (Vaultwarden zit op 8080)
        Z2M_ONBOARD_NO_FAILURE_PAGE = "1";
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
        channel: 25
        network_key: GENERATE
        pan_id: GENERATE
        ext_pan_id: GENERATE
    '';
  };

  # Create Home Assistant template files
  environment.etc."homeassistant/templates/stookwijzer.yaml" = {
    source = ./templates/stookwijzer.yaml;
  };


  # Reset Zigbee USB coordinator bij BOOT — voorkomt SRSP-SYS ping timeout na crash
  # Draait eenmalig bij opstarten (niet bij elke Z2M herstart), want herhaaldelijk
  # resetten veroorzaakt juist commissioning timeouts door timing problemen.
  systemd.services.zigbee-usb-reset = {
    description = "Reset Zigbee USB coordinator";
    before = [ "docker-zigbee2mqtt.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "zigbee-usb-reset" ''
        USB_PATH=""
        for f in /sys/bus/usb/devices/*/idVendor; do
          if grep -q "10c4" "$f" 2>/dev/null; then
            USB_PATH=$(basename "$(dirname "$f")")
            break
          fi
        done
        if [ -n "$USB_PATH" ]; then
          echo "$USB_PATH" > /sys/bus/usb/drivers/usb/unbind || true
          sleep 2
          echo "$USB_PATH" > /sys/bus/usb/drivers/usb/bind || true
          sleep 3
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
  environment.etc."homeassistant/templates/airco.yaml" = {
    source = ./templates/airco.yaml;
  };

  system.activationScripts.homeassistantTemplates = ''
    mkdir -p /var/lib/homeassistant/templates
    cp /etc/homeassistant/templates/stookwijzer.yaml /var/lib/homeassistant/templates/stookwijzer.yaml
    cp /etc/homeassistant/templates/airco.yaml /var/lib/homeassistant/templates/airco.yaml
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
