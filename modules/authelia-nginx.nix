{ lib, ... }:

# Helper module voor Authelia nginx configuratie
# Gebruik dit om gemakkelijk Authelia forward auth toe te voegen aan je services

{
  # Helper functie om Authelia locations toe te voegen aan een virtualHost
  autheliaLocations = {
    # De hoofdlocatie met forward auth
    "/" = {
      extraConfig = ''
        # Forward authentication to Authelia
        auth_request /authelia;
        auth_request_set $user $upstream_http_remote_user;
        auth_request_set $groups $upstream_http_remote_groups;
        auth_request_set $name $upstream_http_remote_name;
        auth_request_set $email $upstream_http_remote_email;

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

    # Authelia verify endpoint
    "/authelia" = {
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
        proxy_pass_request_body off;
        proxy_set_header Content-Length "";
      '';
    };
  };

  # Functie om alleen de auth_request extraConfig te genereren
  # Gebruik dit als je zelf de location al hebt gedefinieerd
  autheliaAuthConfig = ''
    # Forward authentication to Authelia
    auth_request /authelia;
    auth_request_set $user $upstream_http_remote_user;
    auth_request_set $groups $upstream_http_remote_groups;
    auth_request_set $name $upstream_http_remote_name;
    auth_request_set $email $upstream_http_remote_email;

    # Redirect to Authelia login on 401
    error_page 401 =302 https://auth.toorren.net/?rd=$scheme://$http_host$request_uri;

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

  # De /authelia verify endpoint configuratie
  autheliaVerifyLocation = {
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
      proxy_pass_request_body off;
      proxy_set_header Content-Length "";
    '';
  };
}
