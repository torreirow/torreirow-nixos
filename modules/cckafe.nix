{ pkgs, config, ... }:

# Wildcard-domein cckafe.com.
#
# DNS staat bij OpenProvider met een wildcard A-record (*.cckafe.com -> malandro).
# Het wildcard-certificaat (*.cckafe.com + apex) komt uit modules/acme.nix via
# CNAME-delegatie van de ACME-challenge naar de toorren.net Route53-zone.
#
# LET OP: modules/nginx.nix definieert een catch-all default vhost (serverName "_")
# die het toorren.net-cert serveert. Zonder deze eigen vhost zou elk cckafe.com-adres
# op die default belanden en een verkeerd (toorren.net) cert tonen. Deze vhost claimt
# cckafe.com + *.cckafe.com expliciet met het juiste cert.
#
# De site-inhoud staat imperatief in /var/www/cckafe.com (HTML-export van een
# Claude-artifact: index.html + support.js + vendor/react*.js). Nix beheert alleen
# het bestaan/eigenaarschap van de map, niet de bestanden zelf.
{
  # Canonieke site op de apex cckafe.com. De wildcard-alias *.cckafe.com vangt
  # overige subdomeinen af (zodat die niet op de toorren.net-default belanden en
  # het juiste cert krijgen). www.cckafe.com heeft een eigen vhost hieronder die
  # exact matcht en dus wint van deze wildcard.
  services.nginx.virtualHosts."cckafe.com" = {
    serverName = "cckafe.com";
    serverAliases = [ "*.cckafe.com" ];

    forceSSL = true;
    useACMEHost = "cckafe.com";

    root = "/var/www/cckafe.com";

    locations."/" = {
      tryFiles = "$uri $uri/ =404";
    };

    extraConfig = ''
      index index.html;
    '';
  };

  # www.cckafe.com -> 301 naar de apex (canonical). Exacte server_name wint van
  # de wildcard-alias op de apex-vhost.
  services.nginx.virtualHosts."www.cckafe.com" = {
    serverName = "www.cckafe.com";

    forceSSL = true;
    useACMEHost = "cckafe.com";

    locations."/".return = "301 https://cckafe.com$request_uri";
  };

  # Alleen de webroot-map borgen; de inhoud wordt imperatief geplaatst.
  systemd.tmpfiles.rules = [
    "d /var/www/cckafe.com 0755 nginx nginx -"
  ];
}
