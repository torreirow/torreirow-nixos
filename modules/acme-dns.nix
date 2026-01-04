{ config, lib, pkgs, agenix, ... }:

{
age.secrets.rfc2136-env = {
    file = ../secrets/rfc2136.env.age;
    path = "/run/secrets/rfc2136.env";
    owner = "root";
    mode = "0400";
  };

  security.acme = {
  certs."toorren.net" = {
    domain = "*.toorren.net";
    extraDomainNames = [ "toorren.net" ];

    dnsProvider = "rfc2136";

    credentialsFile = "/run/secrets/rfc2136.env";
  };
};

systemd.services.acme-pre = {
    after = [ "knot.service" ];
    requires = [ "knot.service" ];
  };
}

