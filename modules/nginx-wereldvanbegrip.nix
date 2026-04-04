{ config, pkgs, ... }:
{
  security.acme = {
    acceptTerms = true;
    certs."wereldvanbegrip.nl" = {
      email = "wereldvanbegrip@toorren.net";
      extraDomainNames = [ "www.wereldvanbegrip.nl" ];
    };
  };

  services.nginx = {
    virtualHosts."wereldvanbegrip.nl" = {
      root = "/var/www/wereldvanbegrip";
      forceSSL = true;
      enableACME = true;
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
