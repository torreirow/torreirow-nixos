{ config, pkgs, ... }:

{
  # Mosquitto MQTT broker
  virtualisation.oci-containers.containers.mosquitto = {
    image = "eclipse-mosquitto:latest";
    ports = [
      "1883:1883"
      "9001:9001"
    ];
    volumes = [
      "/var/lib/mosquitto/config:/mosquitto/config"
      "/var/lib/mosquitto/data:/mosquitto/data"
      "/var/lib/mosquitto/log:/mosquitto/log"
    ];
    autoStart = true;
  };

  # Zigbee2MQTT - DISABLED (migratie naar ZHA gefaald, zie ZIGBEE_MIGRATION_LOG.md)
  # virtualisation.oci-containers.containers.zigbee2mqtt = {
  #   image = "koenkk/zigbee2mqtt:latest";
  #   ports = [
  #     "8086:8080"
  #   ];
  #   volumes = [
  #     "/var/lib/zigbee2mqtt:/app/data"
  #     "/run/udev:/run/udev:ro"
  #     "/dev:/dev"
  #   ];
  #   extraOptions = [
  #     "--privileged"
  #   ];
  #   environment = {
  #     TZ = "Europe/Amsterdam";
  #   };
  #   autoStart = true;
  # };

  # Firewall
  networking.firewall = {
    allowedTCPPorts = [ 1883 9001 ];  # 8086 verwijderd (Zigbee2MQTT disabled)
  };

  # Nginx reverse proxy voor Zigbee2MQTT frontend - DISABLED
  # services.nginx.virtualHosts."zigbee.toorren.net" = {
  #   forceSSL = true;
  #   useACMEHost = "toorren.net";
  #   locations."/" = {
  #     proxyPass = "http://127.0.0.1:8086";
  #     proxyWebsockets = true;
  #     extraConfig = ''
  #       # Forward authentication to Authelia
  #       auth_request /authelia;
  #       auth_request_set $user $upstream_http_remote_user;
  #       auth_request_set $groups $upstream_http_remote_groups;
  #       auth_request_set $name $upstream_http_remote_name;
  #       auth_request_set $email $upstream_http_remote_email;
  #
  #       # Redirect to Authelia portal on auth failure
  #       error_page 401 = @authelia_portal;
  #
  #       # Pass authentication headers to backend
  #       proxy_set_header Remote-User $user;
  #       proxy_set_header Remote-Groups $groups;
  #       proxy_set_header Remote-Name $name;
  #       proxy_set_header Remote-Email $email;
  #
  #       # Standard proxy headers
  #       proxy_set_header Host $host;
  #       proxy_set_header X-Real-IP $remote_addr;
  #       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  #       proxy_set_header X-Forwarded-Proto $scheme;
  #     '';
  #   };
  #
  #   # Authelia redirect named location
  #   locations."@authelia_portal" = {
  #     extraConfig = ''
  #       return 302 https://auth.toorren.net/?rd=$scheme://$http_host$request_uri;
  #     '';
  #   };
  #
  #   # Authelia authentication endpoint
  #   locations."/authelia" = {
  #     proxyPass = "http://127.0.0.1:9091/api/verify";
  #     extraConfig = ''
  #       internal;
  #       proxy_set_header Host $host;
  #       proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
  #       proxy_set_header X-Forwarded-Method $request_method;
  #       proxy_set_header X-Forwarded-Proto $scheme;
  #       proxy_set_header X-Forwarded-Host $http_host;
  #       proxy_set_header X-Forwarded-Uri $request_uri;
  #       proxy_set_header X-Forwarded-For $remote_addr;
  #       proxy_set_header Content-Length "";
  #       proxy_pass_request_body off;
  #     '';
  #   };
  # };
}
