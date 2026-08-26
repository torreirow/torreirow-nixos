{ config, pkgs, ... }:

# Reverse proxy voor Nextcloud (AIO) draaiend op een andere host.
# Upstream: http://192.168.2.67:11000 (gewoon HTTP; TLS termineert hier op malandro).
# Domein: https://nxc.toorren.net (valt onder de *.toorren.net wildcard-cert).
{
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;

    virtualHosts."nxc.toorren.net" = {
      forceSSL = true;
      useACMEHost = "toorren.net";

      extraConfig = ''
        # Grote uploads toestaan (foto's, video's, sync van grote bestanden)
        client_max_body_size 10G;
        client_body_timeout 3600s;
      '';

      locations."/" = {
        proxyPass = "http://192.168.2.67:11000";
        # Nodig voor Nextcloud notificaties en Talk
        proxyWebsockets = true;
        extraConfig = ''
          # Lange timeouts zodat grote uploads niet sneuvelen
          proxy_read_timeout    3600s;
          proxy_send_timeout    3600s;
          proxy_connect_timeout 3600s;

          # Buffering uit voor streaming/grote overdrachten
          proxy_request_buffering off;
          proxy_buffering off;
        '';
      };
    };
  };
}
