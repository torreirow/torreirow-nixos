{ config, lib, pkgs, agenix, ... }:

age.secrets.rfc2136-env = {
    file = ../secrets/rfc2136.env.age;
    path = "/run/secrets/rfc2136.env";
    owner = "root";
    mode = "0400";
  };

  security.acme = {
  acceptTerms = true;
  defaults.email = "admin@toorren.net";

  certs."toorren.net" = {
    domain = "*.toorren.net";
    extraDomainNames = [ "toorren.net" ];

    dnsProvider = "rfc2136";

    credentialsFile = "/run/secrets/rfc2136.env";
  };
};
}

