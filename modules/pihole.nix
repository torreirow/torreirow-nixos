{ config, pkgs, lib, ... }:

{
  # Pi-hole FTL native NixOS service
  services.pihole-ftl = {
    enable = true;
    
    # Data directory - standaard is /var/lib/pihole
    stateDirectory = "/data/external/pihole";
    
    # Blocklists configuratie
    lists = [
      {
        url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts";
        type = "block";
        enabled = true;
        description = "Steven Black's Unified Hosts";
      }
      {
        url = "https://v.firebog.net/hosts/AdguardDNS.txt";
        type = "block";
        enabled = true;
        description = "AdGuard DNS filter";
      }
      {
        url = "https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt";
        type = "block";
        enabled = true;
        description = "KADhosts";
      }
    ];
    
    # Open firewall poorten automatisch
    openFirewallDNS = false;
    openFirewallDHCP = false;  # Alleen indien DHCP nodig is
    openFirewallWebserver = true;
    
    # Privacy level (0-3, waarbij 0 het meest gedetailleerd is)
    privacyLevel = 0;
    
    # Automatisch query logs verwijderen
    queryLogDeleter.enable = true;
    
    # Pi-hole configuratie
    settings = {
      # DNS instellingen
      dns = {
        # Upstream DNS servers
        upstreams = [
          "1.1.1.1"        # Cloudflare
          "1.0.0.1"        # Cloudflare secundair
          "8.8.8.8"        # Google
          "8.8.4.4"        # Google secundair
        ];
        
        # Local domain
        domain = "home.local";
        domainNeeded = true;
        expandHosts = true;
        
        # Interface om op te luisteren
        interface = "eth0";  # Pas aan naar jouw interface indien nodig
        
        # Extra DNS records (optioneel)
        hosts = [
          "192.168.2.52  pihole.local"
          "192.168.2.1   gateway.local"
        ];
        
        # CNAME records (optioneel)
        cnameRecords = [
          # "alias,target"
        ];
      };
      
      # DHCP configuratie (standaard uitgeschakeld)
      dhcp = {
        active = false;  # Zet op true als je Pi-hole als DHCP server wilt gebruiken
        start = "192.168.2.100";
        end = "192.168.2.200";
        router = "192.168.2.1";
        leaseTime = "24h";
        ipv6 = false;
        rapidCommit = true;
        
        # Statische DHCP leases (optioneel)
        hosts = [
          # "MAC,IP,hostname"
          # "aa:bb:cc:dd:ee:ff,192.168.2.100,laptop"
        ];
        
        resolver = {
          resolveIPv6 = false;
        };
      };
      
      # NTP tijdserver (optioneel uitschakelen)
      ntp = {
        ipv4.active = false;
        ipv6.active = false;
        sync.active = false;
      };
      
      # Webserver en API configuratie
      webserver = {
        # Port wordt geconfigureerd via services.pihole-web.ports
        
        api = {
          # Wachtwoord hash - zie hieronder hoe deze te genereren
          # BELANGRIJK: Eerst misc.readOnly op false zetten, wachtwoord instellen via GUI,
          # dan hash ophalen met: sudo pihole-FTL --config webserver.api.pwhash
          pwhash = "";  # Laat leeg voor eerste keer, stel in via web interface
          
          # Alternatief: gebruik plaintext wachtwoord (NIET VEILIG, alleen voor testing)
          # password = "changeme";
        };
        
        session = {
          timeout = 43200;  # Session timeout in seconden (12 uur)
        };
      };
      
      # Diverse instellingen
      misc = {
        readOnly = false;  # Zet op true om wijzigingen via GUI te blokkeren
      };
    };
    
    # Gebruik dnsmasq configuratie van services.dnsmasq indien gedefinieerd
    useDnsmasqConfig = false;
  };
  
  # Pi-hole Web Interface
  services.pihole-web = {
    enable = true;
    ports = [ "8084" ];  # Interne poort voor web interface (vrije poort in 81xx range)
  };
  
  # Systemd-resolved configuratie om conflicten te voorkomen
  services.resolved = {
    enable = true;
    extraConfig = ''
      DNSStubListener=no
      MulticastDNS=off
    '';
  };
  
  # Nginx reverse proxy configuratie
  services.nginx = {
    enable = true;
    
    virtualHosts."pihole.toorren.net" = {
      # SSL/TLS met wildcard certificaat
      forceSSL = true;
      useACMEHost = "toorren.net";
      
      # Hoofdlocatie - geen Authelia bescherming voor API calls en assets
      locations."/" = {
        proxyPass = "http://127.0.0.1:8084";
        extraConfig = ''
          auth_request /authelia;
          error_page 401 = @authelia_portal;
          
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          
          # WebSocket support
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
        '';
      };
      
      # Authelia redirect named location
      locations."@authelia_portal" = {
        extraConfig = ''
          return 302 https://auth.toorren.net/?rd=$scheme://$http_host$request_uri;
        '';
      };
      
      # Authelia authentication endpoint
      locations."/authelia" = {
        proxyPass = "http://127.0.0.1:9091/api/verify";
        extraConfig = ''
          internal;
          proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
          proxy_set_header X-Forwarded-For $remote_addr;
          proxy_set_header Content-Length "";
          proxy_pass_request_body off;
        '';
      };
    };
  };
  
  # Zorg ervoor dat de data directory bestaat met juiste permissies
  systemd.tmpfiles.rules = [
    "d /data/external/pihole 0755 pihole pihole -"
    "d /data/external/pihole/etc-pihole 0755 pihole pihole -"
    "d /data/external/pihole/etc-dnsmasq.d 0755 pihole pihole -"
    # Fix voor FTL warning over versions bestand
    "f /etc/pihole/versions 0644 pihole pihole - -"
  ];
  
  # Networking hosts (optioneel maar handig)
  networking.hosts = {
    "192.168.2.52" = [ "pihole.toorren.net" "pihole" ];
    "192.168.2.1" = [ "gateway.local" "gateway" ];
  };

  networking.firewall = {
  enable = true;

  extraInputRules = ''
    ip saddr 192.168.2.0/24 udp dport 53 accept
    ip saddr 192.168.2.0/24 tcp dport 53 accept
    udp dport 53 drop
    tcp dport 53 drop
  '';
};

}
