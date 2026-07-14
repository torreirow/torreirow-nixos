{ config, pkgs, lib, ... }:

let
  # Vervang na stap 1.2 (Cloudflare dashboard → Turnstile → Site Key)
  turnstileSiteKey = "0x4AAAAAADpt4F-inu2dVAOF";

  contactHtml = pkgs.writeTextFile {
    name = "wereldvanbegrip-contact.html";
    text = ''
      <!DOCTYPE html>
      <html lang="nl">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Contact - Wereld van Begrip</title>
        <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
        <style>
          body { font-family: sans-serif; max-width: 600px; margin: 2rem auto; padding: 0 1rem; }
          label { display: block; margin-top: 1rem; font-weight: bold; }
          input, textarea { width: 100%; padding: .5rem; margin-top: .25rem; box-sizing: border-box; }
          textarea { height: 150px; }
          button { margin-top: 1.5rem; padding: .75rem 2rem; background: #2563eb; color: #fff; border: none; cursor: pointer; }
          button:hover { background: #1d4ed8; }
          .success { color: green; margin-top: 1rem; display: none; }
        </style>
      </head>
      <body>
        <h1>Contact</h1>
        <p class="success" id="bedankt">Bedankt voor uw bericht! We nemen zo snel mogelijk contact met u op.</p>
        <form action="https://mailer.toorren.net/send" method="POST">
          <label for="naam">Naam</label>
          <input type="text" id="naam" name="naam" required>

          <label for="email">E-mailadres</label>
          <input type="email" id="email" name="email" required>

          <label for="bericht">Bericht</label>
          <textarea id="bericht" name="bericht" required></textarea>

          <!-- Honeypot: verborgen voor mensen, ingevuld door bots -->
          <div style="position:absolute;left:-9999px;top:-9999px;" aria-hidden="true">
            <label for="website">Laat dit veld leeg</label>
            <input type="text" id="website" name="website" tabindex="-1" autocomplete="off">
          </div>

          <div class="cf-turnstile" data-sitekey="${turnstileSiteKey}"></div>

          <button type="submit">Verstuur</button>
        </form>
        <script>
          if (new URLSearchParams(window.location.search).has('verzonden')) {
            document.getElementById('bedankt').style.display = 'block';
          }
        </script>
      </body>
      </html>
    '';
  };
in
{
  services.nginx = {
    virtualHosts."wereldvanbegrip.nl" = {
      root = "/var/www/wereldvanbegrip";
      forceSSL = true;
      useACMEHost = "wereldvanbegrip.nl";
      locations."/" = {
        tryFiles = "$uri $uri/ =404";
      };
      locations."= /contact" = {
        return = "301 /contact/";
      };
      locations."^~ /contact/" = {
        extraConfig = ''
          alias /var/www/wereldvanbegrip-contact/;
          try_files $uri index.html =404;
        '';
      };
      extraConfig = ''
        index index.html;
      '';
    };

    virtualHosts."www.wereldvanbegrip.nl" = {
      forceSSL = true;
      useACMEHost = "wereldvanbegrip.nl";
      locations."/" = {
        return = "301 https://wereldvanbegrip.nl$request_uri";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/www/wereldvanbegrip-contact 0755 nginx nginx -"
    "L /var/www/wereldvanbegrip-contact/index.html - - - - ${contactHtml}"
  ];
}
