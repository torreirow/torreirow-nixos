{ config, lib, pkgs, ... }:

{
  # Cockpit met Fail2ban dashboard
  services.cockpit = {
    enable = true;
    port = 9095;
    settings = {
      WebService = {
        AllowUnencrypted = true;
        Origins = lib.mkForce "https://cockpit.toorren.net https://toorren.net";
      };
    };
  };
  
  # Nginx proxy met Authelia (exact zelfde als WG UI)
  services.nginx.virtualHosts."cockpit.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";
    
    locations."/" = {
      proxyPass = "http://127.0.0.1:9095";
      proxyWebsockets = true;
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
    
    # Authelia redirects
    locations."@authelia_portal" = {
      extraConfig = ''
        return 302 https://auth.toorren.net/?rd=$scheme://$http_host$request_uri;
      '';
    };
    
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
  };
  
  # Firewall: Cockpit poort 9095 NIET direct open (alleen via nginx/443)
  # Geen extra firewall config nodig - nginx opent automatisch 443
}

