{ config, pkgs, ... }:

# Reverse proxy voor Nextcloud (AIO) draaiend op een andere host.
# Upstream: http://192.168.2.67:11000 (gewoon HTTP; TLS termineert hier op malandro).
# Domein: https://nxc.toorren.net (valt onder de *.toorren.net wildcard-cert).
#
# bobadela1 (de upstream-host) gaat elke avond 23:00 bewust uit en wordt 09:00 door
# wake-bobadela1 gewekt. Tussendoor is de upstream onbereikbaar. Daarom:
#   - korte proxy_connect_timeout (3s): de TCP-handshake faalt snel i.p.v. tot de
#     lange upload-timeout te blijven hangen (zie beslissing in de OpenSpec-change
#     catch-nextcloud-sleeping). De send/read-timeouts blijven 3600s voor grote uploads.
#   - error_page 502/503/504 => een interne @sleeping-location die een tijdbewuste
#     onderhoudspagina als HTTP 503 serveert, gescoped op ALLEEN deze vhost.
{
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;

    virtualHosts."nxc.toorren.net" = {
      forceSSL = true;
      useACMEHost = "toorren.net";

      extraConfig = ''
        # Grote uploads toestaan (foto's, video's, sync van grote bestanden)
        client_max_body_size 10G;
        client_body_timeout 3600s;
      '';

      locations."/" = {
        proxyPass = "http://192.168.2.67:11000";
        # Nodig voor Nextcloud notificaties en Talk
        proxyWebsockets = true;
        extraConfig = ''
          # Snel falen op de TCP-handshake: staat bobadela1 uit, dan komt de
          # SYN niet aan en willen we binnen enkele seconden naar @sleeping i.p.v.
          # tot de upload-timeout te blijven hangen. Dit begrenst ALLEEN de connect,
          # niet de transfer (zie send/read hieronder).
          proxy_connect_timeout 3s;

          # Lange timeouts zodat grote uploads niet sneuvelen (transfer-fase)
          proxy_read_timeout    3600s;
          proxy_send_timeout    3600s;

          # Buffering uit voor streaming/grote overdrachten
          proxy_request_buffering off;
          proxy_buffering off;

          # Onbereikbare upstream (502/504) of upstream-onderhoud (503) netjes
          # afvangen met de slaappagina, als HTTP 503. Geen proxy_intercept_errors
          # nodig: de connect-fout wordt door nginx zelf opgewekt.
          error_page 502 503 504 =503 @sleeping;
        '';
      };

      # Interne onderhoudspagina. Alleen bereikbaar via de error_page-redirect
      # hierboven (internal), nooit direct opvraagbaar.
      locations."@sleeping" = {
        root = "/var/www/nxc";
        extraConfig = ''
          internal;
          add_header Retry-After 1800 always;
          add_header Cache-Control "no-store" always;
          try_files /sleeping.html =503;
        '';
      };
    };
  };

  # Tijdbewuste onderhoudspagina. De JS-klok draait in de browser van de bezoeker
  # (lokale apparaattijd) en kiest de tekst; de statuscode (503) staat daar los van.
  environment.etc."nginx-nxc/sleeping.html".text = ''
    <!DOCTYPE html>
    <html lang="nl">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Nextcloud is even niet bereikbaar</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
                background: #18222c;
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                color: #fff;
            }
            .container { text-align: center; padding: 2rem; max-width: 600px; }
            .icon { font-size: 5rem; line-height: 1; margin-bottom: 1.5rem; }
            h1 { font-size: 2rem; margin-bottom: 1rem; }
            p { font-size: 1.2rem; margin-bottom: 1.5rem; opacity: 0.9; }
            .retry {
                display: inline-block;
                padding: 0.9rem 1.8rem;
                background: rgba(255,255,255,0.2);
                color: #fff;
                text-decoration: none;
                border: 1px solid rgba(255,255,255,0.3);
                border-radius: 8px;
                cursor: pointer;
                transition: all 0.3s ease;
            }
            .retry:hover { background: rgba(255,255,255,0.3); transform: translateY(-2px); }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="icon" id="icon">&#9729;</div>
            <h1 id="title">Nextcloud is even niet bereikbaar</h1>
            <p id="msg">Een ogenblik geduld.</p>
            <a class="retry" onclick="location.reload()">Opnieuw proberen</a>
        </div>
        <script>
            (function () {
                var h = new Date().getHours();
                var sleeping = (h >= 23 || h < 9);
                var icon = document.getElementById("icon");
                var title = document.getElementById("title");
                var msg = document.getElementById("msg");
                if (sleeping) {
                    icon.innerHTML = "&#128564;";
                    title.textContent = "Nextcloud slaapt";
                    msg.textContent = "De cloud is 's nachts uitgeschakeld en komt rond 09:00 vanzelf weer online. Probeer het straks opnieuw.";
                } else {
                    icon.innerHTML = "&#9729;";
                    title.textContent = "Nextcloud is onverwacht onbereikbaar";
                    msg.textContent = "De cloud zou nu bereikbaar moeten zijn maar reageert niet. Dit wordt automatisch opnieuw geprobeerd.";
                }
            })();
        </script>
    </body>
    </html>
  '';

  systemd.tmpfiles.rules = [
    "d /var/www/nxc 0755 nginx nginx -"
    "L /var/www/nxc/sleeping.html - - - - /etc/nginx-nxc/sleeping.html"
  ];
}
