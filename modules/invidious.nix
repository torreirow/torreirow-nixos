{ config, pkgs, ... }:

{
  # Invidious YouTube frontend
  services.invidious = {
    enable = true;
    domain = "invidious.local";  # Pas dit aan naar jouw domein
    port = 3000;

    database = {
      host = "127.0.0.1";
      port = 5432;
      createLocally = true;
    };

    settings = {
      db = {
        user = "invidious";
        dbname = "invidious";
      };

      # Privacy instellingen
      registration_enabled = false;
      login_enabled = false;
      captcha_enabled = false;

      # Externe diensten
      external_port = 443;
      https_only = false;  # Zet op true als je SSL gebruikt
      
      # Performance
      pool_size = 100;
      
      # Interface instellingen
      default_user_preferences = {
        locale = "nl";
        region = "NL";
        quality = "dash";
        player_style = "youtube";
        dark_mode = "dark";
      };
    };
  };

  # Nginx reverse proxy (optioneel)
  services.nginx = {
    
    virtualHosts."toorren.net" = {  # Pas aan naar jouw domein
      useACMEHost = "toorren.net";
      forceSSL = true;
      
      locations."/" = {
        proxyPass = "http://127.0.0.1:3000";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header X-Forwarded-For $remote_addr;
          proxy_set_header Host $host;
          proxy_http_version 1.1;
          proxy_set_header Connection "keep-alive";
        '';
      };
    };
  };

  # Firewall
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
