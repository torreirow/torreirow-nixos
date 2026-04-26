{ config, pkgs, ... }:

{
  services.nginx = {
    virtualHosts."boaz.toorren.net" = {
      root = "/var/www/boaz";

      forceSSL = true;
      useACMEHost = "toorren.net";

      locations."/" = {
        tryFiles = "$uri $uri/ =404";
        extraConfig = ''
          auth_request /authelia;
          error_page 401 = @authelia_portal;
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

      extraConfig = ''
        index index.html;
      '';
    };
  };

  # Create boaz website directory
  systemd.tmpfiles.rules = [
    "d /var/www/boaz 0755 root root -"
  ];
}
