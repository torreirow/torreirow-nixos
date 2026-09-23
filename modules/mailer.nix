{ config, pkgs, lib, ... }:

let
  cfg = config.services.contactMailer;

  phpScript = pkgs.writeTextFile {
    name = "mailer-send.php";
    text = ''
      <?php
      // Nette foutpagina i.p.v. een blanco response.
      function fail($code, $msg) {
          http_response_code($code);
          header("Content-Type: text/html; charset=UTF-8");
          $back = htmlspecialchars($_SERVER['HTTP_REFERER'] ?? "/", ENT_QUOTES);
          $safe = htmlspecialchars($msg, ENT_QUOTES);
          echo "<!doctype html><html lang=\"nl\"><head><meta charset=\"utf-8\">";
          echo "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>Formulier</title>";
          echo "<style>body{font-family:sans-serif;max-width:600px;margin:3rem auto;padding:0 1rem;line-height:1.6;color:#141414}a{color:#2563eb}</style>";
          echo "</head><body><p>" . $safe . "</p><p><a href=\"" . $back . "\">&larr; Ga terug / Go back</a></p></body></html>";
          exit;
      }

      if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
          fail(405, "Ongeldig verzoek. / Invalid request.");
      }

      // Honeypot: stil negeren als het veld ingevuld is
      if (!empty($_POST['website'])) {
          http_response_code(200);
          exit;
      }

      // Origin whitelist: alleen geconfigureerde domeinen
      $recipients = json_decode('${builtins.toJSON cfg.recipients}', true);
      $origin = $_SERVER['HTTP_ORIGIN'] ?? "";
      if (empty($origin)) {
          $referer = $_SERVER['HTTP_REFERER'] ?? "";
          $parsed  = parse_url($referer);
          $origin  = ($parsed['scheme'] ?? "") . "://" . ($parsed['host'] ?? "");
      }
      $domain = parse_url($origin, PHP_URL_HOST) ?: "";
      if (!array_key_exists($domain, $recipients)) {
          fail(403, "Verzoek geweigerd. / Request denied.");
      }
      $toEmail = $recipients[$domain];

      // Cap (self-hosted) server-side validatie.
      // De widget levert een hidden veld 'cap-token'; wij verifiëren dat via
      // de reCAPTCHA-compatibele siteverify-API met een JSON-body
      // {"secret", "response"} (het token gaat mee als 'response').
      $token = $_POST['cap-token'] ?? "";
      if (empty($token)) {
          fail(403, "Bevestig eerst dat je geen robot bent. / Please confirm you're human first.");
      }
      $secretKey = trim(file_get_contents('${cfg.capSecretFile}'));
      $ch = curl_init('${cfg.capBaseUrl}/${cfg.capSiteKey}/siteverify');
      curl_setopt_array($ch, [
          CURLOPT_POST           => true,
          CURLOPT_HTTPHEADER     => ['Content-Type: application/json'],
          CURLOPT_POSTFIELDS     => json_encode(['secret' => $secretKey, 'response' => $token]),
          CURLOPT_RETURNTRANSFER => true,
          CURLOPT_TIMEOUT        => 10,
          // PHP-FPM heeft geen SSL_CERT_FILE in de omgeving; geef de CA-bundle
          // expliciet mee zodat de HTTPS-call naar Cap niet op SSL-verificatie faalt.
          CURLOPT_CAINFO         => '${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt',
      ]);
      $raw      = curl_exec($ch);
      $curlErr  = curl_error($ch);
      $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
      curl_close($ch);
      $result = json_decode($raw, true);
      if (!($result['success'] ?? false)) {
          error_log("mailer: Cap siteverify faalde http=$httpCode curl=\"$curlErr\" body=" . substr((string)$raw, 0, 300));
          fail(403, "Verificatie mislukt. Probeer het opnieuw. / Verification failed. Please try again.");
      }

      // Valideer verplichte velden
      $naam    = strip_tags(trim($_POST['naam'] ?? ""));
      $email   = filter_var(trim($_POST['email'] ?? ""), FILTER_VALIDATE_EMAIL);
      $bericht = strip_tags(trim($_POST['bericht'] ?? ""));
      if (empty($naam) || !$email || empty($bericht)) {
          fail(400, "Vul alle verplichte velden in. / Please fill in all required fields.");
      }

      // Verstuur via Postfix (lokale MTA)
      $subject = "Contactformulier - " . $domain;
      $body    = "Naam: $naam\nE-mail: $email\n\n$bericht";
      $headers = implode("\r\n", [
          "From: noreply@toorren.net",
          "Reply-To: $email",
          "Content-Type: text/plain; charset=UTF-8",
      ]);
      mail($toEmail, $subject, $body, $headers);

      // Redirect terug met bevestiging
      $back = $_SERVER['HTTP_REFERER'] ?? "https://$domain/";
      header("Location: $back?verzonden=1");
      exit;
    '';
  };

in
{
  options.services.contactMailer = {
    enable = lib.mkEnableOption "contactformulier mailer via PHP-FPM en Postfix";

    recipients = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Map van domeinnaam naar ontvangst-emailadres.";
      example = lib.literalExpression ''
        { "wereldvanbegrip.nl" = "info@wereldvanbegrip.nl"; }
      '';
    };

    capBaseUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://cap.toorren.net";
      description = "Basis-URL van de self-hosted Cap CAPTCHA-server.";
    };

    capSiteKey = lib.mkOption {
      type = lib.types.str;
      description = "Cap site-key (publiek) gebruikt in de siteverify-URL.";
      example = "eaa5abea30";
    };

    capSecretFile = lib.mkOption {
      type = lib.types.str;
      description = "Pad naar het bestand met de Cap key-secret (via agenix).";
      example = "/run/secrets/cap-mailer-secret";
    };
  };

  config = lib.mkIf cfg.enable {

    services.phpfpm.pools.mailer = {
      user = "nginx";
      group = "nginx";

      phpPackage = pkgs.php83.buildEnv {
        extensions = { enabled, all }: enabled ++ (with all; [ curl openssl ]);
        extraConfig = ''
          # Gebruik de setgid-postdrop wrapper (NixOS), niet de rauwe store-binary:
          # anders kan postdrop niet in de maildrop schrijven en hangt mail().
          sendmail_path = /run/wrappers/bin/sendmail -t -i
          allow_url_fopen = On
          log_errors = On
          error_log = /dev/stderr
        '';
      };

      settings = {
        "listen.owner" = "nginx";
        "listen.group" = "nginx";
        "pm" = "ondemand";
        "pm.max_children" = 5;
        "pm.process_idle_timeout" = "10s";
        # Zodat PHP error_log()-regels in journald (phpfpm-mailer) verschijnen.
        "catch_workers_output" = "yes";
      };
    };

    services.nginx = {
      commonHttpConfig = ''
        limit_req_zone $binary_remote_addr zone=contactform:10m rate=5r/m;
      '';

      virtualHosts."mailer.toorren.net" = {
        forceSSL = true;
        useACMEHost = "toorren.net";
        root = "/var/www/mailer";

        locations."= /send" = {
          extraConfig = ''
            limit_except POST { deny all; }
            limit_req zone=contactform burst=3 nodelay;
            include ${pkgs.nginx}/conf/fastcgi_params;
            fastcgi_pass unix:${config.services.phpfpm.pools.mailer.socket};
            fastcgi_param SCRIPT_FILENAME ${phpScript};
          '';
        };
      };
    };

    users.users.nginx.extraGroups = [ "keys" ];

    systemd.tmpfiles.rules = [
      "d /var/www/mailer 0755 nginx nginx -"
    ];
  };
}
