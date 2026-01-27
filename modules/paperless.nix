{ config, pkgs, lib, agenix, ... }:
{
  services.nginx.virtualHosts."docs.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";
    locations."/" = {
      proxyPass = "http://127.0.0.1:8181";
      proxyWebsockets = false;
      extraConfig = ''
        auth_request /authelia;
        error_page 401 = @authelia_portal;

        proxy_http_version 1.1;
        proxy_set_header Connection "";

        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  # Authelia redirect named location
  locations."@authelia_portal" = {
    extraConfig = ''
        return 302 https://auth.toorren.net/?rd=$scheme://$http_host$request_uri;
    '';
  };

    # Authelia authentication endpoint
    locations."/authelia" = {
      proxyPass = "http://127.0.0.1:9091/api/verify";
      extraConfig = ''
        internal;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header Content-Length "";
        proxy_pass_request_body off;
      '';
    };
  };

#  networking.firewall.interfaces.docker0.allowedTCPPorts = [ 5432 ];
}
