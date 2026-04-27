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

      # Generieke error pages voor alle sites
      error_page 403 /errors/403.html;
      error_page 404 /errors/404.html;
    '';

    virtualHosts."wildcard-placeholder" = {
      default = true;
      serverName = "_";

      addSSL = true;
      sslCertificate = "/var/lib/acme/toorren.net/fullchain.pem";
      sslCertificateKey = "/var/lib/acme/toorren.net/key.pem";

      root = "/var/www/default";

      locations."/" = {
        tryFiles = "$uri $uri/ =404";
      };

      locations."/errors/" = {
        root = "/var/www";
        extraConfig = ''
          internal;
        '';
      };

      extraConfig = ''
        index index.html;
      '';

    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  environment.etc."nginx-default/index.html".text = ''
    <!DOCTYPE html>
    <html lang="nl">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>toorrenaer</title>
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                color: #fff;
            }
            .container {
                text-align: center;
                padding: 2rem;
                max-width: 800px;
            }
            .landing-image {
                max-width: 600px;
                width: 100%;
                height: auto;
                margin: 2rem auto;
                display: block;
                border-radius: 12px;
                box-shadow: 0 12px 24px rgba(0,0,0,0.3);
            }
            h1 {
                font-size: 3.5rem;
                font-weight: 700;
                margin-bottom: 1rem;
                text-shadow: 0 4px 8px rgba(0,0,0,0.2);
            }
            p {
                font-size: 1.4rem;
                opacity: 0.9;
                margin-bottom: 2rem;
            }
            .footer {
                margin-top: 3rem;
                font-size: 0.9rem;
                opacity: 0.7;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>toorrenaer</h1>
            <img src="/landing.png" alt="Toorrenaer" class="landing-image" onerror="this.style.display='none'">
            <p>nothing to be found here.</p>
            <div class="footer">
                <p>© 2026 toorrenaer.nl</p>
            </div>
        </div>
    </body>
    </html>
  '';

  environment.etc."nginx-errors/404.html".text = ''
    <!DOCTYPE html>
    <html lang="nl">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>404 - Pagina niet gevonden</title>
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                color: #fff;
            }
            .container {
                text-align: center;
                padding: 2rem;
                max-width: 600px;
            }
            .error-code {
                font-size: 8rem;
                font-weight: 700;
                line-height: 1;
                margin-bottom: 1rem;
                text-shadow: 0 4px 8px rgba(0,0,0,0.2);
            }
            .error-image {
                max-width: 400px;
                width: 100%;
                height: auto;
                margin: 2rem auto;
                display: block;
                border-radius: 8px;
                box-shadow: 0 8px 16px rgba(0,0,0,0.2);
            }
            h1 {
                font-size: 2rem;
                margin-bottom: 1rem;
            }
            p {
                font-size: 1.2rem;
                margin-bottom: 2rem;
                opacity: 0.9;
            }
            .home-link {
                display: inline-block;
                padding: 1rem 2rem;
                background: rgba(255,255,255,0.2);
                color: #fff;
                text-decoration: none;
                border-radius: 8px;
                transition: all 0.3s ease;
                backdrop-filter: blur(10px);
                border: 1px solid rgba(255,255,255,0.3);
            }
            .home-link:hover {
                background: rgba(255,255,255,0.3);
                transform: translateY(-2px);
                box-shadow: 0 4px 12px rgba(0,0,0,0.2);
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="error-code">404</div>
            <img src="/errors/404.png" alt="404 Error" class="error-image" onerror="this.style.display='none'">
            <h1>Pagina niet gevonden</h1>
            <p>De pagina die je zoekt bestaat niet of is verplaatst.</p>
            <a href="/" class="home-link">← Terug naar home</a>
        </div>
    </body>
    </html>
  '';

  environment.etc."nginx-errors/403.html".text = ''
    <!DOCTYPE html>
    <html lang="nl">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>403 - Toegang Geweigerd</title>
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
                background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                color: #fff;
            }
            .container {
                text-align: center;
                padding: 2rem;
                max-width: 600px;
            }
            .error-code {
                font-size: 8rem;
                font-weight: 700;
                line-height: 1;
                margin-bottom: 1rem;
                text-shadow: 0 4px 8px rgba(0,0,0,0.2);
            }
            .error-image {
                max-width: 400px;
                width: 100%;
                height: auto;
                margin: 2rem auto;
                display: block;
                border-radius: 8px;
                box-shadow: 0 8px 16px rgba(0,0,0,0.2);
            }
            h1 {
                font-size: 2rem;
                margin-bottom: 1rem;
            }
            p {
                font-size: 1.2rem;
                margin-bottom: 2rem;
                opacity: 0.9;
            }
            .home-link {
                display: inline-block;
                padding: 1rem 2rem;
                background: rgba(255,255,255,0.2);
                color: #fff;
                text-decoration: none;
                border-radius: 8px;
                transition: all 0.3s ease;
                backdrop-filter: blur(10px);
                border: 1px solid rgba(255,255,255,0.3);
            }
            .home-link:hover {
                background: rgba(255,255,255,0.3);
                transform: translateY(-2px);
                box-shadow: 0 4px 12px rgba(0,0,0,0.2);
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="error-code">403</div>
            <img src="/errors/404.png" alt="403 Error" class="error-image" onerror="this.style.display='none'">
            <h1>Toegang Geweigerd</h1>
            <p>Je hebt geen toegang tot deze pagina.</p>
            <a href="/" class="home-link">← Terug naar home</a>
        </div>
    </body>
    </html>
  '';

  # Landing page image
  environment.etc."nginx-default/landing.png" = {
    source = ./static/landing.png;
    mode = "0644";
  };

  # 404 error page image
  environment.etc."nginx-errors/404.png" = {
    source = ./static/404.png;
    mode = "0644";
  };

  systemd.tmpfiles.rules = [
    "d /var/www/default 0755 nginx nginx -"
    "L /var/www/default/index.html - - - - /etc/nginx-default/index.html"
    "L /var/www/default/landing.png - - - - /etc/nginx-default/landing.png"
    "d /var/www/errors 0755 nginx nginx -"
    "L /var/www/errors/403.html - - - - /etc/nginx-errors/403.html"
    "L /var/www/errors/404.html - - - - /etc/nginx-errors/404.html"
    "L /var/www/errors/404.png - - - - /etc/nginx-errors/404.png"
  ];
}

