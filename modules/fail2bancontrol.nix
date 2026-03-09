{ config, pkgs, ... }:

{
  # fail2bancontrol - Web GUI for fail2ban management
  virtualisation.oci-containers = {
    backend = "docker";
    containers.fail2bancontrol = {
      image = "oweitman/fail2bancontrol:latest";
      ports = [
        "127.0.0.1:9096:9000"
      ];
      volumes = [
        "/var/run/fail2ban:/var/run/fail2ban:ro"
        "/var/log/nginx:/var/log/nginx:ro"
      ];
      environment = {
        TZ = "Europe/Amsterdam";
      };
      autoStart = true;
    };
  };

  # Nginx reverse proxy with Authelia authentication
  services.nginx.enable = true;
  services.nginx.virtualHosts."fail2ban.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";
    locations."/" = {
      proxyPass = "http://127.0.0.1:9096";
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
}
