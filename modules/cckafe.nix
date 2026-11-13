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
# De site is een Hugo-build (repo cckafe-website); release.sh rsynct die naar
#   /var/www/cckafe.com        (productie, ./release.sh)
#   /var/www/test.cckafe.com   (test,      ./release.sh test)
# Nix beheert alleen het bestaan/eigenaarschap van de mappen, niet de bestanden zelf.
let
  # Statische Hugo-site met eigen 404-pagina (alleen via error_page, niet direct als
  # 200). Zolang 404.html ontbreekt valt nginx terug op zijn eigen 404.
  #
  # Caching: CSS en JS zijn door Hugo gefingerprint (`site.min.<hash>.css`,
  # `app.min.<hash>.js`), dus die mogen een jaar immutable. De HTML krijgt
  # `no-cache`: release.sh rsynct de site imperatief, en zonder dat blijft een
  # oude pagina in de browsercache hangen. Fonts/afbeeldingen/audio hebben geen
  # hash in de naam en krijgen daarom een week.
  hugoSite = root: {
    forceSSL = true;
    useACMEHost = "cckafe.com";
    inherit root;

    locations."/" = {
      tryFiles = "$uri $uri/ =404";
      extraConfig = ''
        add_header Cache-Control "no-cache";
      '';
    };

    locations."~* \\.(css|js)$".extraConfig = ''
      add_header Cache-Control "public, max-age=31536000, immutable";
    '';

    locations."~* \\.(woff2|png|jpe?g|webp|svg|ico|mp3)$".extraConfig = ''
      add_header Cache-Control "public, max-age=604800";
    '';

    locations."= /404.html".extraConfig = ''
      internal;
    '';

    extraConfig = ''
      index index.html;
      error_page 404 /404.html;
    '';
  };
in
{
  # Canonieke site op de apex cckafe.com. De wildcard-alias *.cckafe.com vangt
  # overige subdomeinen af (zodat die niet op de toorren.net-default belanden en
  # het juiste cert krijgen). www.cckafe.com heeft een eigen vhost hieronder die
  # exact matcht en dus wint van deze wildcard.
  services.nginx.virtualHosts."cckafe.com" = hugoSite "/var/www/cckafe.com" // {
    serverName = "cckafe.com";
    serverAliases = [ "*.cckafe.com" ];
  };

  # Testomgeving. Exacte server_name wint van de wildcard-alias op de apex-vhost.
  # Niet indexeerbaar: zie services.aiBlocklist.sites."test.cckafe.com".noindex.
  services.nginx.virtualHosts."test.cckafe.com" = hugoSite "/var/www/test.cckafe.com" // {
    serverName = "test.cckafe.com";
  };

  # www.cckafe.com -> 301 naar de apex (canonical). Exacte server_name wint van
  # de wildcard-alias op de apex-vhost.
  services.nginx.virtualHosts."www.cckafe.com" = {
    serverName = "www.cckafe.com";

    forceSSL = true;
    useACMEHost = "cckafe.com";

    locations."/".return = "301 https://cckafe.com$request_uri";
  };

  # Alleen de webroot-mappen borgen; de inhoud wordt imperatief geplaatst.
  systemd.tmpfiles.rules = [
    "d /var/www/cckafe.com 0755 nginx nginx -"
    "d /var/www/test.cckafe.com 0755 nginx nginx -"
  ];
}
