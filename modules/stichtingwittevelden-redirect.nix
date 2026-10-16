{ config, pkgs, ... }:

# Redirect: stichtingwittevelden.nl -> https://www.stichtingwittevelden.nl
#
# De site zelf draait op Cloudflare Pages (www CNAME -> stwv-development.pages.dev);
# alleen de apex wijst (A-record in Route53) naar malandro. Een apex kan geen CNAME
# zijn, dus malandro vangt 'm op en stuurt door naar www.
#
# Cert via HTTP-01 (enableACME): de NixOS nginx-module zet dan webroot en overschrijft
# de geërfde route53-dnsProvider uit modules/acme.nix naar null.
{
  services.nginx.virtualHosts."stichtingwittevelden.nl" = {
    forceSSL = true;
    enableACME = true;

    locations."/".return = "301 https://www.stichtingwittevelden.nl$request_uri";
  };
}
