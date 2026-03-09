{ config, lib, pkgs, ... }:

{
  # Fail2ban configuration for NixOS 25.11

  services.fail2ban = {
    enable = true;

    # Whitelist trusted IPs
    ignoreIP = [
      "127.0.0.1/8"
      "::1"
      "192.168.2.0/24"  # Local network
    ];

    # Ban action (default is iptables-multiport)
    banaction = "iptables-multiport";

    # Ban action for IPv6
    banaction-allports = "iptables-allports";

    # Jail configurations
    jails = {
      # SSH protection
      sshd = {
        settings = {
          enabled = true;
          port = "ssh";
          filter = "sshd";
          maxretry = 5;
          findtime = "10m";
          bantime = "10m";
        };
      };
    } // lib.optionalAttrs config.services.nginx.enable {
      # Nginx protection (only if nginx is enabled)
      nginx-http-auth = {
        settings = {
          enabled = true;
          filter = "nginx-http-auth";
          port = "http,https";
          logpath = "/var/log/nginx/error.log";
          maxretry = 5;
          findtime = "10m";
          bantime = "10m";
        };
      };

      nginx-limit-req = {
        settings = {
          enabled = true;
          filter = "nginx-limit-req";
          port = "http,https";
          logpath = "/var/log/nginx/error.log";
          maxretry = 10;
          findtime = "10m";
          bantime = "10m";
        };
      };
    };
  };
}
