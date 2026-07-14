{ config, pkgs, ... }:

{
  # Firewall
  networking.firewall = {
    enable = true;
    allowedUDPPorts = [ 51820 ];
    checkReversePath = "loose";
    trustedInterfaces = [ "docker0" ];
  };

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # Laad WireGuard kernel module (iptables via nftables compat, geen legacy modules nodig)
  boot.kernelModules = [ "wireguard" ];

  # NAT voor Docker bridge
  networking.nat = {
    enable = true;
    externalInterface = "enp3s0";
    internalInterfaces = [ "docker0" ];
  };

  # wg-easy DOCKER container (GEEN host networking)
  virtualisation.oci-containers = {
    backend = "docker";
    containers.wg-easy = {
      image = "ghcr.io/wg-easy/wg-easy:latest";
      ports = [
        "51820:51820/udp"
        "51821:51821/tcp"
      ];
      volumes = [ "/var/lib/wg-easy:/etc/wireguard" ];
      environment = {
        WG_HOST = "wg.toorren.net";
        PASSWORD_HASH = "$2a$12$2kO66Q7Xg4JI/n2QzXW9ROTZ0O2yJA/NJCuYMDl.YU9g8PS.ZYJsi";
        WG_DEFAULT_DNS = "1.1.1.1";
        WG_ALLOWED_IPS = "0.0.0.0/0";
        # Gebruik iptables-nft i.p.v. iptables-legacy (kernel 6.x heeft geen iptable_nat module)
        WG_POST_UP = "iptables-nft -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE; iptables-nft -A INPUT -p udp -m udp --dport 51820 -j ACCEPT; iptables-nft -A FORWARD -i wg0 -j ACCEPT; iptables-nft -A FORWARD -o wg0 -j ACCEPT;";
        WG_POST_DOWN = "iptables-nft -t nat -D POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE; iptables-nft -D INPUT -p udp -m udp --dport 51820 -j ACCEPT; iptables-nft -D FORWARD -i wg0 -j ACCEPT; iptables-nft -D FORWARD -o wg0 -j ACCEPT;";
      };
      capabilities = {
        NET_ADMIN = true;
        SYS_MODULE = false;
      };
      autoStart = true;
    };
  };

  services.nginx.enable = true;
  services.nginx.virtualHosts."wg.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";
    locations."/" = {
      proxyPass = "http://127.0.0.1:51821";
      proxyWebsockets = true;
      extraConfig = ''
        # Forward authentication to Authelia
        auth_request /authelia;
        auth_request_set $user $upstream_http_remote_user;
        auth_request_set $groups $upstream_http_remote_groups;
        auth_request_set $name $upstream_http_remote_name;
        auth_request_set $email $upstream_http_remote_email;

        # Redirect to Authelia portal on auth failure
        error_page 401 = @authelia_portal;
        error_page 403 = @authelia_forbidden;

        # Pass authentication headers to backend
        proxy_set_header Remote-User $user;
        proxy_set_header Remote-Groups $groups;
        proxy_set_header Remote-Name $name;
        proxy_set_header Remote-Email $email;

        # Standard proxy headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };

    # Authelia redirect named locations
    locations."@authelia_portal" = {
      extraConfig = ''
        return 302 https://auth.toorren.net/?rd=$scheme://$http_host$request_uri;
      '';
    };

    locations."@authelia_forbidden" = {
      extraConfig = ''
        return 403;
      '';
    };


    # Authelia authentication endpoint
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
}

