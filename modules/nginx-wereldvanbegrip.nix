{ config, pkgs, ... }:
{
  services.nginx = {
    virtualHosts."wereldvanbegrip.nl" = {
      root = "/var/www/wereldvanbegrip";
      forceSSL = true;
      useACMEHost = "wereldvanbegrip.nl";
      locations."/" = {
        tryFiles = "$uri $uri/ =404";
      };
      extraConfig = ''
        index index.html;
      '';
    };

    virtualHosts."www.wereldvanbegrip.nl" = {
      forceSSL = true;
      useACMEHost = "wereldvanbegrip.nl";
      locations."/" = {
        return = "301 https://wereldvanbegrip.nl$request_uri";
      };
    };
  };
}
