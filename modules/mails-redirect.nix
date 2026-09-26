{ config, pkgs, ... }:

# Redirect: mails.toorren.net -> https://nxc.toorren.net/apps/mail
# Valt onder de *.toorren.net wildcard-cert (useACMEHost = "toorren.net").

{
  services.nginx.virtualHosts."mails.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";

    locations."/" = {
      return = "301 https://nxc.toorren.net/apps/mail";
    };
  };
}
