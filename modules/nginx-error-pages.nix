{ lib, ... }:

# Generieke 403/404-pagina's (error_page in modules/nginx.nix) op elke vhost.
#
# error_page op http-niveau leidt om naar een URI binnen de vhost zelf; zonder deze
# location vond alleen de catch-all de pagina en gaf elke andere vhost een kale 404
# (bijv. GET op mailer.toorren.net/send: 403 werd 404). Een vhost met een eigen
# error_page (cckafe.com) erft de http-regels niet en houdt zijn eigen pagina's.
#
# Bewust geen /errors/: een app achter een proxy die dat pad zelf gebruikt, zou
# erdoor worden overschaduwd.
{
  options.services.nginx.virtualHosts = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      config.locations."/_nginx-errors/" = {
        alias = "/var/www/errors/";
        extraConfig = ''
          internal;
        '';
      };
    });
  };
}
