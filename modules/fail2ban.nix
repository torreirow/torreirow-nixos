{ config, lib, pkgs, ... }:

{
  # Fail2ban configuration for NixOS 25.11
  # The 'backend' option has been removed in newer versions

  services.fail2ban = {
    enable = true;

    # Maximum retry attempts before banning
    maxretry = 5;

    # Ban time in seconds (default: 600 = 10 minutes)
    bantime = "10m";

    # Time window for counting failures
    findtime = "10m";

    # Whitelist trusted IPs
    ignoreIP = [
      "127.0.0.1/8"
      "::1"
      "192.168.2.0/24"  # Local network
    ];

    # Jail configurations
    jails = {
      # SSH protection
      sshd = ''
        enabled = true
        port = ssh
        filter = sshd
        maxretry = 5
      '';
    } // lib.optionalAttrs config.services.nginx.enable {
      # Nginx protection (only if nginx is enabled)
      nginx-http-auth = ''
        enabled = true
        filter = nginx-http-auth
        logpath = /var/log/nginx/error.log
        maxretry = 5
      '';

      nginx-limit-req = ''
        enabled = true
        filter = nginx-limit-req
        logpath = /var/log/nginx/error.log
        maxretry = 10
      '';
    };
  };
}
