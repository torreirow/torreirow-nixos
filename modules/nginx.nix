{ pkgs, config, ... }:

{
  services.nginx = {
    enable = true;

    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts."wildcard-placeholder" = {
      default = true;
      serverName = "_";

      root = "/var/www/default";

      locations."/" = {
        tryFiles = "$uri $uri/ =404";
      };

      extraConfig = ''
        index index.html;
      '';

      sslCertificate = "/var/lib/acme/toorren.net/fullchain.pem";
      sslCertificateKey = "/var/lib/acme/toorren.net/key.pem";
      forceSSL = true;
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  environment.etc."nginx-default/index.html".text = ''
    <!doctype html>
    <html>
      <head><title>toorrenaer</title></head>
      <body>
        <h1>toorrenaer</h1>
        <p>nothing to be found here.</p>
      </body>
    </html>
  '';

  systemd.tmpfiles.rules = [
    "d /var/www/default 0755 nginx nginx -"
    "L /var/www/default/index.html - - - - /etc/nginx-default/index.html"
  ];
}

