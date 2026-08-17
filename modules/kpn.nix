{ config, pkgs, ... }:

# Reverse proxy: kpn.toorren.net -> http://192.168.2.254 (KPN modem)
# Beschermd met Authelia. Lokale netwerken (192.168/10/172.16) worden in
# modules/authelia.nix ge-bypassed; externe toegang vereist 2FA (group:users).

{
  services.nginx.virtualHosts."kpn.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";

    # Authelia verify endpoint
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
        # Authelia authenticatie (bypass voor lokale IPs in modules/authelia.nix)
        auth_request /authelia;
        auth_request_set $auth_status $upstream_status;
        error_page 401 = @authelia_portal;

        # De modem weigert onbekende Host-headers; stuur zijn eigen IP mee.
        proxy_set_header Host 192.168.2.254;
      '';
    };
  };
}
