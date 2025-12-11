{
  services.jitsi-meet = {
    enable = true;
    hostName = "meet.dutchyland.net"; # change this to your domain
  };

  services.jitsi-videobridge.openFirewall = true;


  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
