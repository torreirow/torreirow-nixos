{ config, pkgs, lib, ... }:

# wereldvanbegrip.nl — statische Hugo-site (uitgerold via de Hugo release.sh naar
# /var/www/wereldvanbegrip). Het contactformulier zit in de Hugo-site zelf en POST
# naar de self-hosted mailer (mailer.toorren.net) met Cap-CAPTCHA; er is hier dus
# geen aparte /contact-pagina meer nodig.
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
