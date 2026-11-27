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

    # Foto's van meet-ups (modules/cckafe-photos). De dienst schrijft per album
    # alleen een manifest; de foto's zelf blijven in Immich en worden hieronder
    # geproxyt. De manifesten staan in /var/lib en niet in de webroot, omdat
    # release.sh die met `rsync --delete` overschrijft.
    #
    # `^~` is nodig: zonder dat wint de regex-locatie hierboven voor .webp/.jpg en
    # worden de bestanden in de webroot gezocht (404) in plaats van via deze alias.
    locations."^~ /photos/" = {
      alias = "/var/lib/cckafe-photos/";
      extraConfig = ''
        autoindex off;
        add_header Cache-Control "public, max-age=604800";
      '';
    };

    # De foto's zelf: /immich/<asset-id>.webp haalt Immich's preview op, met de
    # API-sleutel in een header uit een age-secret (een kant-en-klaar
    # proxy_set_header-snippet, zodat de tokenwaarde nooit in de nix-store staat).
    #
    # De rewrite laat alleen een asset-id door: al het andere houdt zijn pad en
    # loopt bij Immich op een 404 stuk, dus er is geen andere route naar de API.
    locations."^~ /immich/" = {
      proxyPass = "http://127.0.0.1:2283";
      extraConfig = ''
        rewrite "^/immich/([0-9a-f-]{36})\.webp$" /api/assets/$1/thumbnail?size=preview break;
        include ${config.age.secrets.immich-cckafe-photos-nginx-key.path};
        proxy_hide_header x-api-key;
        proxy_hide_header set-cookie;
        add_header Cache-Control "public, max-age=604800";
      '';
    };

    locations."= /404.html".extraConfig = ''
      internal;
    '';

    # Lijst van meet-ups en hun albums (/meetups/index.txt, een TSV). De
    # fotodienst (modules/cckafe-photos) leest dit bestand rechtstreeks van
    # schijf; via HTTP is het niet nodig en dus niet bereikbaar.
    locations."= /meetups/index.txt" = {
      extraConfig = ''
        return 404;
      '';
    };

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

  # De API-sleutel voor de proxy op /immich/, als kant-en-klaar nginx-snippet.
  # Eigendom van nginx, zodat de master het bij het opstarten kan lezen; de
  # waarde staat nooit in een Nix-optie (die is wereldleesbaar in de nix-store).
  age.secrets.immich-cckafe-photos-nginx-key = {
    file = ../secrets/immich-cckafe-photos-nginx-key.age;
    owner = "nginx";
    group = "nginx";
    mode = "0400";
  };

  # Alleen de webroot-mappen borgen; de inhoud wordt imperatief geplaatst.
  systemd.tmpfiles.rules = [
    "d /var/www/cckafe.com 0755 nginx nginx -"
    "d /var/www/test.cckafe.com 0755 nginx nginx -"
  ];
}
