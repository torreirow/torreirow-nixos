{ config, pkgs, ... }:

# Simpele reverse proxy: kpn.toorren.net -> http://192.168.2.254 (KPN modem)
#
# LET OP: dit is een KALE proxy zonder authenticatie. Het modem-beheer wordt
# hiermee direct via kpn.toorren.net ontsloten. Wil je auth ervoor, gebruik
# het edge.toorren.net-patroon uit modules/kpn-modem.nix (Authelia).

{
  services.nginx.virtualHosts."kpn.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";

    locations."/" = {
      proxyPass = "http://192.168.2.254";
      proxyWebsockets = true;

      # De modem weigert onbekende Host-headers; stuur zijn eigen IP mee.
      extraConfig = ''
        proxy_set_header Host 192.168.2.254;
      '';
    };
  };
}
