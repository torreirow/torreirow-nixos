{ config, pkgs, ... }:

# KPN Modem reverse proxy via edge.toorren.net
# Proxies naar 192.168.2.254:443 met Authelia authenticatie voor externe verzoeken
#
# BELANGRIJK: Om lokale netwerk verzoeken te bypassen, voeg toe aan Authelia configuratie:
#
#   access_control:
#     rules:
#       - domain: edge.toorren.net
#         policy: bypass
#         networks:
#           - 192.168.0.0/16
#           - 10.0.0.0/8
#           - 172.16.0.0/12
#           - 127.0.0.1/8
#       - domain: edge.toorren.net
#         policy: two_factor

{
  services.nginx.virtualHosts."edge.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";

    # Authelia verify endpoint
    locations."/authelia" = {
      proxyPass = "http://127.0.0.1:9091/api/verify";
      extraConfig = ''
        internal;
        proxy_set_header Host $host;
        proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
        proxy_set_header X-Forwarded-Method $request_method;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $http_host;
        proxy_set_header X-Forwarded-Uri $request_uri;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header Content-Length "";
        proxy_pass_request_body off;
      '';
    };

    # Authelia portal redirect
    locations."@authelia_portal" = {
      extraConfig = ''
        return 302 https://auth.toorren.net/?rd=$scheme://$http_host$request_uri;
      '';
    };

    # Hoofdlocatie met Authelia authenticatie
    locations."/" = {
      proxyPass = "http://192.168.2.254";
      proxyWebsockets = true;

      extraConfig = ''
        # Authelia authenticatie (bypass voor lokale IPs configureren in Authelia)
        auth_request /authelia;
        auth_request_set $auth_status $upstream_status;

        # Als auth faalt, redirect naar Authelia
        error_page 401 = @authelia_portal;

        # SSL verificatie uitschakelen voor het modem (self-signed cert)
        proxy_ssl_verify off;

        # Proxy headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;

        # Timeouts verhogen voor modem interface
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
      '';
    };
  };
}
