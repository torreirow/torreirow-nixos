{ config, lib, pkgs, ... }:

{
  age.secrets.route53-env = {
    file = ../secrets/route53.age;
    path = "/run/secrets/route53.env";
    owner = "root";
    mode = "0400";
  };

  security.acme = {
    acceptTerms = true;

    defaults = {
      email = "admin@toorren.net";
      dnsProvider = "route53";
      environmentFile = "/run/secrets/route53.env";
    };

    certs."toorren.net" = {
      domain = "*.toorren.net";
      extraDomainNames = [ "toorren.net" ];
      group = "nginx";
    };

    certs."wereldvanbegrip.nl" = {
      domain = "*.wereldvanbegrip.nl";
      extraDomainNames = [ "wereldvanbegrip.nl" ];
      group = "nginx";
      # DNS bij OpenProvider, gebruikt CNAME delegation naar toorren.net (Route53)
      # CNAME: _acme-challenge.wereldvanbegrip.nl -> _acme-challenge.wvb.toorren.net
      # CNAME: _acme-challenge.www.wereldvanbegrip.nl -> _acme-challenge.wvb.toorren.net
      dnsResolver = "1.1.1.1:53";  # Use Cloudflare DNS to follow CNAME
      dnsPropagationCheck = true;
    };

    certs."cckafe.com" = {
      domain = "*.cckafe.com";
      extraDomainNames = [ "cckafe.com" ];
      group = "nginx";
      email = "admin@cckafe.com";  # per-cert override op de default admin@toorren.net
      # DNS bij OpenProvider (wildcard A-record *.cckafe.com -> malandro).
      # ACME-challenge is naar toorren.net (Route53) gedelegeerd via CNAME:
      # CNAME: _acme-challenge.cckafe.com -> _acme-challenge.cckafe.toorren.net
      # (dekt zowel *.cckafe.com als de apex; beide gebruiken _acme-challenge.cckafe.com)
      dnsResolver = "1.1.1.1:53";  # Cloudflare DNS om de CNAME te volgen
      dnsPropagationCheck = true;
    };
  };
  users.users.nginx.extraGroups = [ "acme" ];
}
