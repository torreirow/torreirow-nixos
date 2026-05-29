{ config, pkgs, ... }:

{
  services.nginx.virtualHosts."opsknight.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";
    locations."/" = {
      proxyPass = "http://192.168.2.25:9097";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host $host;
      '';
    };
  };
}
