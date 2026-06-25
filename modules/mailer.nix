{ config, pkgs, lib, ... }:

let
  cfg = config.services.contactMailer;

  phpScript = pkgs.writeTextFile {
    name = "mailer-send.php";
    text = ''
      <?php
      if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
          http_response_code(405);
          exit;
      }

      // Honeypot: stil negeren als het veld ingevuld is
      if (!empty($_POST['website'])) {
          http_response_code(200);
          exit;
      }

      // Origin whitelist: alleen geconfigureerde domeinen
      $recipients = json_decode('${builtins.toJSON cfg.recipients}', true);
      $origin = $_SERVER['HTTP_ORIGIN'] ?? '';
      if (empty($origin)) {
          $referer = $_SERVER['HTTP_REFERER'] ?? '';
          $parsed  = parse_url($referer);
          $origin  = ($parsed['scheme'] ?? '') . '://' . ($parsed['host'] ?? '');
      }
      $domain = parse_url($origin, PHP_URL_HOST) ?: '';
      if (!array_key_exists($domain, $recipients)) {
          http_response_code(403);
          exit;
      }
      $toEmail = $recipients[$domain];

      // Cloudflare Turnstile server-side validatie
      $token = $_POST['cf-turnstile-response'] ?? '';
      if (empty($token)) {
          http_response_code(403);
          exit;
      }
      $secretKey = trim(file_get_contents('${cfg.turnstileSecretFile}'));
      $ctx = stream_context_create(['http' => [
          'method'  => 'POST',
          'header'  => 'Content-Type: application/x-www-form-urlencoded',
          'content' => http_build_query(['secret' => $secretKey, 'response' => $token]),
      ]]);
      $result = json_decode(
          file_get_contents('https://challenges.cloudflare.com/turnstile/v0/siteverify', false, $ctx),
          true
      );
      if (!($result['success'] ?? false)) {
          http_response_code(403);
          exit;
      }

      // Valideer verplichte velden
      $naam    = strip_tags(trim($_POST['naam'] ?? ''));
      $email   = filter_var(trim($_POST['email'] ?? ''), FILTER_VALIDATE_EMAIL);
      $bericht = strip_tags(trim($_POST['bericht'] ?? ''));
      if (empty($naam) || !$email || empty($bericht)) {
          http_response_code(400);
          exit;
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

    turnstileSecretFile = lib.mkOption {
      type = lib.types.str;
      description = "Pad naar het bestand met de Cloudflare Turnstile secret key (via agenix).";
      example = "/run/secrets/turnstile-secret";
    };
  };

  config = lib.mkIf cfg.enable {

    services.phpfpm.pools.mailer = {
      user = "nginx";
      group = "nginx";

      phpPackage = pkgs.php83.buildEnv {
        extensions = { enabled, all }: enabled ++ (with all; [ curl openssl ]);
        extraConfig = ''
          sendmail_path = ${pkgs.postfix}/bin/sendmail -t -i
          allow_url_fopen = On
        '';
      };

      settings = {
        "listen.owner" = "nginx";
        "listen.group" = "nginx";
        "pm" = "ondemand";
        "pm.max_children" = 5;
        "pm.process_idle_timeout" = "10s";
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

    systemd.tmpfiles.rules = [
      "d /var/www/mailer 0755 nginx nginx -"
    ];
  };
}
