{ config, lib, pkgs, ... }:

# Status-dashboard voor malandro (status.toorren.net).
#
# Zet de gedeclareerde config (soll) af tegen de live runtime-status (ist) en
# toont per applicatie een oordeel: gezond / kapot / orphan.
#
# - soll wordt hier bij `nixos-rebuild` gebakken naar /etc/status-page/configured.json
#   uit oci-containers, nginx.virtualHosts en een curated lijst native services.
# - ist wordt live-per-request verzameld door modules/status-page.py
#   (docker ps / systemctl is-active / ss -tlnp).
# - nginx-vhost + Authelia forward-auth volgen exact het patroon van cockpit.nix.

let
  port = 9099;

  # Curated lijst van native (niet-docker) services die ertoe doen.
  # Handmatig bijhouden: unitnamen zoals `systemctl` ze kent (zonder .service).
  # Docker-apps (vaultwarden, paperless, ...) komen automatisch via de
  # container-inventaris hieronder — niet hier opnemen.
  nativeServices = [
    "nginx"
    "authelia-main"
    "grafana"
    "mysql"
    "postgresql"
    "postfix"
    "prometheus"
    "alertmanager"
    "fail2ban"
    "redis-authelia"
  ];

  # soll: OCI-containers uit de NixOS-config.
  containers = lib.mapAttrsToList (name: c: {
    inherit name;
    image = c.image;
    ports = c.ports or [ ];
  }) config.virtualisation.oci-containers.containers;

  # soll: nginx virtualHosts. Best-effort upstream/type-extractie.
  vhosts = lib.mapAttrsToList (name: v: {
    inherit name;
    proxyPass = (v.locations."/" or { }).proxyPass or null;
    redirect = v.globalRedirect or null;
    ssl = (v.forceSSL or false) || (v.addSSL or false);
  }) config.services.nginx.virtualHosts;

  configuredJson = builtins.toJSON {
    inherit containers vhosts nativeServices;
  };
in
{
  # soll bakken naar /etc/status-page/configured.json
  environment.etc."status-page/configured.json".text = configuredJson;

  # Collector-service: luistert alleen op localhost, draait als root voor
  # read-only toegang tot de docker-socket en systemd.
  systemd.services.status-page = {
    description = "Status dashboard collector (soll x ist)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "docker.service" ];

    environment = {
      CONFIGURED_JSON = "/etc/status-page/configured.json";
      STATUS_PORT = toString port;
      STATUS_BIND = "127.0.0.1";
      DOCKER_BIN = "${pkgs.docker}/bin/docker";
      SYSTEMCTL_BIN = "${pkgs.systemd}/bin/systemctl";
      SS_BIN = "${pkgs.iproute2}/bin/ss";
    };

    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${./status-page.py}";
      Restart = "on-failure";
      RestartSec = 5;

      # Hardening — read-only observatie; geen schrijftoegang nodig.
      # ProtectSystem=strict laat /run (docker.sock) ongemoeid.
      DynamicUser = false;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ProtectKernelTunables = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK" ];
    };
  };

  # Nginx reverse proxy met Authelia forward-auth (patroon uit cockpit.nix).
  services.nginx.virtualHosts."status.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";

    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      extraConfig = ''
        # Authelia authenticatie
        auth_request /authelia;
        auth_request_set $user $upstream_http_remote_user;
        auth_request_set $groups $upstream_http_remote_groups;
        auth_request_set $name $upstream_http_remote_name;
        auth_request_set $email $upstream_http_remote_email;

        error_page 401 = @authelia_portal;

        proxy_set_header Remote-User $user;
        proxy_set_header Remote-Groups $groups;
        proxy_set_header Remote-Name $name;
        proxy_set_header Remote-Email $email;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };

    locations."@authelia_portal" = {
      extraConfig = ''
        return 302 https://auth.toorren.net/?rd=$scheme://$http_host$request_uri;
      '';
    };

    locations."/authelia" = {
      proxyPass = "http://127.0.0.1:9091/api/verify";
      extraConfig = ''
        internal;
        proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
        proxy_set_header X-Forwarded-Method $request_method;
        proxy_set_header X-Forwarded-Host $http_host;
        proxy_set_header X-Forwarded-Uri $request_uri;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header Content-Length "";
        proxy_pass_request_body off;
      '';
    };
  };

  # Collector-poort 9099 wordt NIET in de firewall geopend (alleen via nginx/443).
}
