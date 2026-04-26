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
      credentialsFile = "/run/secrets/route53.env";
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
  };
  users.users.nginx.extraGroups = [ "acme" ];
}
