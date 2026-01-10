{ pkgs, config, ... }:

# Fixed HTTPS support for catch-all server
{
  services.nginx = {
    enable = true;
    #sslCertificate = "/var/lib/acme/toorren.net/fullchain.pem";
    #sslCertificateKey = "/var/lib/acme/toorren.net/key.pem";

    defaultListenAddresses = [ "0.0.0.0" ];
    defaultSSLListenPort = 443;
    defaultHTTPListenPort = 80;

    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    commonHttpConfig = ''
      limit_req_zone $binary_remote_addr zone=vwlogin:10m rate=5r/m;
    '';

    virtualHosts."wildcard-placeholder" = {
      default = true;
      serverName = "_";
      listen = [
        { addr = "0.0.0.0"; port = 80; }
        { addr = "[::]"; port = 80; }
        { addr = "0.0.0.0"; port = 443; ssl = true; }
        { addr = "[::]"; port = 443; ssl = true; }
      ];

      forceSSL = false;
      sslCertificate = "/var/lib/acme/toorren.net/fullchain.pem";
      sslCertificateKey = "/var/lib/acme/toorren.net/key.pem";

      root = "/var/www/default";

      locations."/" = {
        tryFiles = "$uri $uri/ =404";
      };

      extraConfig = ''
        index index.html;
      '';

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

