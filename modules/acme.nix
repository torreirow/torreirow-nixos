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
  };
  users.users.nginx.extraGroups = [ "acme" ];
}
