{ config, pkgs, ... }:

{
  virtualisation.oci-containers = {
    backend = "docker";

    containers.vaultwarden = {
      image = "vaultwarden/server:latest";
      environment = {
        DOMAIN = "https://vw.toorren.net";
        ROCKET_PORT = "8080"; 
        ROCKET_ADDRESSES = "127.0.0.1";
        TZ = "Europe/Amsterdam";
      };
      volumes = [
        "/var/lib/vaultwarden:/data"
      ];
      extraOptions = [
        "--network=host"
        "--read-only"
        "--cap-drop=ALL"
        "--security-opt=no-new-privileges"
      ];
    };
  };


  services.nginx.virtualHosts."vw.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";

    locations."/" = {
      proxyPass = "http://127.0.0.1:8080";
      proxyWebsockets = true;

      extraConfig = ''
        limit_req zone=vwlogin burst=10 nodelay;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_request_buffering off;

        client_max_body_size 10M;

        add_header X-Frame-Options "DENY" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer" always;
        add_header Content-Security-Policy "
        default-src 'none';
        style-src 'self';
        script-src 'self';
        connect-src 'self';
        img-src 'self' data: blob:;
        font-src 'self';
        frame-ancestors 'none';
        " always;
      '';
    };
  };


  #services.nginx.virtualHosts."vw.toorren.net" = {
  #  forceSSL = true;
  #  useACMEHost = "toorren.net";
  #  locations = {
  #    "/" = {
  #      proxyPass = "http://127.0.0.1:8080";
  #      proxyWebsockets = true;
  #    };
  #  };
  #};

}
