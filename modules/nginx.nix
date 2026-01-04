{ pkgs, config,  ... }:

{
  security.acme = {
    acceptTerms = true;
    defaults.email = "wouter@toorren.net";
  };

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;


    virtualHosts."default" = {
      default = true;  
      serverName = "_";

      root = "/var/www/default";
      extraConfig = ''
        index index.html;
      '';

      locations."/" = {
        tryFiles = "$uri $uri/ =404";
      };
    };
  };

  # NGINX Landingpage
  environment.etc."nginx-default/index.html".text = ''
    <!doctype html>
    <html>
      <head><title>Toorrenaer</title></head>
      <body>
        <h1>Toorrenaer</h1>
        <p>Nothing the be found here.</p>
      </body>
    </html>
  '';

  systemd.tmpfiles.rules = [
    "d /var/www/default 0755 nginx nginx -"
    "L /var/www/default/index.html - - - - /etc/nginx-default/index.html"
  ];

  networking.firewall = {
    allowedTCPPorts = [ 80 443 ];
  };


}
