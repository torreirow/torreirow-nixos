{ config, lib, pkgs, ... }:

{
  services.jitsi-meet = {
    enable = true;
    hostName = "meet.toorren.net";

    nginx.enable = true;

    prosody.enable = true;
    prosody.lockdown = true;

    config = {
      defaultLang = "nl";
      enableWelcomePage = false;
    };

    secureDomain.enable = true;
  };

  # Gebruik bestaand *.toorren.net wildcard cert; override de mkDefault van jitsi-meet module
  services.nginx.virtualHosts."meet.toorren.net" = {
    enableACME = false;
    useACMEHost = "toorren.net";
    forceSSL = true;
  };

  # Jitsi Videobridge media (WebRTC)
  services.jitsi-videobridge.openFirewall = true;
  networking.firewall.allowedUDPPortRanges = [{ from = 10000; to = 20000; }];
}
