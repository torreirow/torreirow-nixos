{ config, lib, pkgs, ... }:

# GrainWork — besloten bijbelstudiesite (grainwork.dutchyland.net) achter Pocket ID.
#
#   browser ─▶ nginx grainwork.dutchyland.net ─auth_request─▶ oauth2-proxy (127.0.0.1:8099)
#                 │ root /var/www/grainwork                       │ OIDC, groep "grainwork"
#                 │ (release.sh in de repo torreirow/grainwork)    ▼
#                 └ /welkom/ + statische assets zonder login     Pocket ID id.dutchyland.net (127.0.0.1:8098) ─▶ Postgres
#
# Uitrollen in fasen (zie openspec/changes/archive/*-grainwork-hosting/design.md):
#   enable           wildcard-cert *.dutchyland.net (vereist CNAME _acme-challenge bij OpenProvider)
#   pocketId.enable  fase 1: Pocket ID, met setupLock alleen bereikbaar vanaf thuis/WireGuard
#                    → /setup, admin + passkey, SMTP, groep "grainwork", OIDC-client aanmaken
#   site.enable      fase 2: oauth2-proxy + de site; setupLock daarna uit
#
# Secrets (agenix; de repo is publiek dus nooit plaintext in .nix):
#   grainwork-pocket-id-db.age              DB_CONNECTION_STRING (handmatig: postgres://user:pw@127.0.0.1:5432/db?sslmode=disable)
#   grainwork-pocket-id-encryption-key.age  ENCRYPTION_KEY (willekeurig)
#   grainwork-oauth2-proxy-client.age       OAUTH2_PROXY_CLIENT_ID=… en OAUTH2_PROXY_CLIENT_SECRET=… (uit de Pocket ID-GUI)
#   grainwork-oauth2-proxy-cookie.age       cookie secret: precies 32 tekens (openssl rand -hex 16); uit een
#                                           bestand gebruikt oauth2-proxy de ruwe bytes, geen base64

let
  cfg = config.services.grainwork;
  tls = cfg.acmeHost != null;
  scheme = if tls then "https" else "http";

  # Zonder login bereikbaar: de welkomstpagina en wat die nodig heeft (geen studie-inhoud).
  publicLocations = {
    "/welkom/" = { };
    "~ ^/(css|js|img|fontawesome|webfonts)/" = { };
    "~ ^/style\\.main\\.[^/]+\\.css$" = { };
    "= /favicon.ico" = { };
    "= /robots.txt" = { };
  };
in
{
  options.services.grainwork = {
    enable = lib.mkEnableOption "GrainWork-hosting (wildcard-certificaat *.dutchyland.net)";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "grainwork.dutchyland.net";
      description = "Domein van de site.";
    };

    idDomain = lib.mkOption {
      type = lib.types.str;
      default = "id.dutchyland.net";
      description = "Domein van Pocket ID.";
    };

    acmeHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "dutchyland.net";
      description = "ACME-certificaat voor beide vhosts; null = alleen HTTP (voor de VM-test).";
    };

    agenix = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Secrets uit secrets/grainwork-*.age halen; uit in de VM-test, die eigen bestanden opgeeft.";
    };

    pocketId = {
      enable = lib.mkEnableOption "Pocket ID op idDomain (fase 1)";

      port = lib.mkOption {
        type = lib.types.port;
        default = 8098;
        description = "Poort van Pocket ID op 127.0.0.1.";
      };

      setupLock = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Pocket ID alleen bereikbaar vanaf allowedNetworks. Zolang er geen admin is, kan
          iedereen via /setup admin worden; zet dit pas uit na de eerste setup.
        '';
      };

      allowedNetworks = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "127.0.0.1" "192.168.2.0/24" "10.8.0.0/24" ];
        description = "Netwerken die Pocket ID mogen bereiken zolang setupLock aan staat (thuis-LAN, WireGuard).";
      };

      dbConnectionFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Bestand met DB_CONNECTION_STRING; null = SQLite in de dataDir.";
      };

      encryptionKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Bestand met ENCRYPTION_KEY.";
      };
    };

    site = {
      enable = lib.mkEnableOption "de site achter oauth2-proxy (fase 2)";

      root = lib.mkOption {
        type = lib.types.path;
        default = "/var/www/grainwork";
        description = "Webroot; gevuld door release.sh.";
      };

      proxyPort = lib.mkOption {
        type = lib.types.port;
        default = 8099;
        description = "Poort van oauth2-proxy op 127.0.0.1.";
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "grainwork";
        description = "Pocket ID-groep met toegang tot de site.";
      };

      clientEnvFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Env-bestand met OAUTH2_PROXY_CLIENT_ID en OAUTH2_PROXY_CLIENT_SECRET.";
      };

      cookieSecretFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Bestand met het cookie secret van oauth2-proxy.";
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # ── certificaat ───────────────────────────────────────────────────────────
    (lib.mkIf (cfg.acmeHost == "dutchyland.net") {
      # DNS bij OpenProvider (wildcard A-record *.dutchyland.net -> malandro; devos.dutchyland.net
      # is een eigen CNAME naar Cloudflare Pages en valt hier niet onder).
      # ACME-challenge gedelegeerd naar toorren.net (Route53), zelfde patroon als cckafe.com:
      #   CNAME: _acme-challenge.dutchyland.net -> _acme-challenge.dutchyland.toorren.net
      security.acme.certs."dutchyland.net" = {
        domain = "*.dutchyland.net";
        extraDomainNames = [ "dutchyland.net" ];
        group = "nginx";
        dnsResolver = "1.1.1.1:53";
        dnsPropagationCheck = true;
      };
    })

    # ── secrets ───────────────────────────────────────────────────────────────
    (lib.mkIf (cfg.agenix && cfg.pocketId.enable) {
      age.secrets.grainwork-pocket-id-db.file = ../secrets/grainwork-pocket-id-db.age;
      age.secrets.grainwork-pocket-id-encryption-key.file = ../secrets/grainwork-pocket-id-encryption-key.age;
      services.grainwork.pocketId = {
        dbConnectionFile = lib.mkDefault config.age.secrets.grainwork-pocket-id-db.path;
        encryptionKeyFile = lib.mkDefault config.age.secrets.grainwork-pocket-id-encryption-key.path;
      };
    })
    (lib.mkIf (cfg.agenix && cfg.site.enable) {
      age.secrets.grainwork-oauth2-proxy-client.file = ../secrets/grainwork-oauth2-proxy-client.age;
      age.secrets.grainwork-oauth2-proxy-cookie.file = ../secrets/grainwork-oauth2-proxy-cookie.age;
      services.grainwork.site = {
        clientEnvFile = lib.mkDefault config.age.secrets.grainwork-oauth2-proxy-client.path;
        cookieSecretFile = lib.mkDefault config.age.secrets.grainwork-oauth2-proxy-cookie.path;
      };
    })

    # ── fase 1: Pocket ID ─────────────────────────────────────────────────────
    (lib.mkIf cfg.pocketId.enable {
      assertions = [{
        assertion = cfg.pocketId.encryptionKeyFile != null;
        message = "services.grainwork.pocketId.encryptionKeyFile is verplicht (Pocket ID v2 weigert te starten zonder).";
      }];

      services.pocket-id = {
        enable = true;
        settings = {
          APP_URL = "${scheme}://${cfg.idDomain}";
          TRUST_PROXY = true;
          ANALYTICS_DISABLED = true;
          HOST = "127.0.0.1";
          PORT = cfg.pocketId.port;
        };
        # systemd LoadCredential: de bestanden mogen van root blijven.
        credentials = {
          ENCRYPTION_KEY = cfg.pocketId.encryptionKeyFile;
        } // lib.optionalAttrs (cfg.pocketId.dbConnectionFile != null) {
          DB_CONNECTION_STRING = cfg.pocketId.dbConnectionFile;
        };
      };

      # Herstel: eenmalige inloglink voor een gebruiker (bijv. passkey kwijt). Gebruik:
      #   sudo grainwork-login-link <gebruikersnaam of e-mail>
      environment.systemPackages = [
        (pkgs.writeShellScriptBin "grainwork-login-link" ''
          set -euo pipefail
          if [ "$#" -ne 1 ]; then
            echo "Gebruik: sudo grainwork-login-link <gebruikersnaam of e-mail>" >&2
            exit 2
          fi
          ${lib.optionalString (cfg.pocketId.dbConnectionFile != null) ''
            DB_CONNECTION_STRING="$(cat ${toString cfg.pocketId.dbConnectionFile})"
            export DB_CONNECTION_STRING
          ''}
          ENCRYPTION_KEY="$(cat ${toString cfg.pocketId.encryptionKeyFile})"
          export ENCRYPTION_KEY APP_URL=${lib.escapeShellArg "${scheme}://${cfg.idDomain}"}
          cd ${config.services.pocket-id.dataDir}
          exec ${lib.getExe config.services.pocket-id.package} one-time-access-token "$1"
        '')
      ];

      services.nginx.virtualHosts.${cfg.idDomain} = {
        forceSSL = tls;
        useACMEHost = cfg.acmeHost;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.pocketId.port}";
          recommendedProxySettings = true;
          extraConfig = lib.optionalString cfg.pocketId.setupLock (
            lib.concatMapStrings (net: "allow ${net};\n") cfg.pocketId.allowedNetworks + "deny all;\n"
          );
        };
      };
    })

    # ── fase 2: site achter oauth2-proxy ──────────────────────────────────────
    (lib.mkIf cfg.site.enable {
      assertions = [
        {
          assertion = cfg.pocketId.enable;
          message = "services.grainwork.site vereist services.grainwork.pocketId (de OIDC-provider).";
        }
        {
          assertion = cfg.site.clientEnvFile != null && cfg.site.cookieSecretFile != null;
          message = "services.grainwork.site vereist clientEnvFile en cookieSecretFile.";
        }
      ];

      services.oauth2-proxy = {
        enable = true;
        provider = "oidc";
        oidcIssuerUrl = "${scheme}://${cfg.idDomain}";
        keyFile = cfg.site.clientEnvFile; # OAUTH2_PROXY_CLIENT_ID + OAUTH2_PROXY_CLIENT_SECRET
        cookie = {
          secretFile = cfg.site.cookieSecretFile;
          name = "_grainwork";
          expire = "720h0m0s"; # 30 dagen ingelogd blijven
          # Elk uur verversen bij Pocket ID: uitgezette accounts en leden die uit de groep zijn
          # gehaald verliezen zo binnen een uur hun toegang (vereist offline_access).
          refresh = "1h0m0s";
          secure = tls;
        };
        httpAddress = "http://127.0.0.1:${toString cfg.site.proxyPort}";
        redirectURL = "${scheme}://${cfg.domain}/oauth2/callback";
        upstream = [ "static://202" ];
        email.domains = [ "*" ];
        scope = "openid email profile groups offline_access";
        approvalPrompt = "auto"; # toestemmingsscherm alleen de eerste keer
        setXauthrequest = true;
        reverseProxy = true;
        trustedProxyIP = [ "127.0.0.1" ];
        extraConfig = {
          skip-provider-button = true;
          code-challenge-method = "S256";
          oidc-groups-claim = "groups";
          # /oauth2/sign_out?rd=https://<idDomain>/api/oidc/end-session: ook bij Pocket ID uitloggen.
          whitelist-domain = cfg.idDomain;
        };
        nginx = {
          domain = cfg.domain;
          virtualHosts.${cfg.domain}.allowed_groups = [ cfg.site.group ];
        };
      };

      services.nginx.virtualHosts.${cfg.domain} = {
        forceSSL = tls;
        useACMEHost = cfg.acmeHost;
        root = cfg.site.root;
        locations = {
          "/".tryFiles = "$uri $uri/ =404";
        } // lib.mapAttrs (_: _: {
          tryFiles = "$uri $uri/ =404";
          extraConfig = "auth_request off;";
        }) publicLocations;
        extraConfig = ''
          index index.html;
        '';
      };

      # Alleen de webroot borgen; de inhoud komt van release.sh.
      systemd.tmpfiles.rules = lib.optional (!lib.hasPrefix builtins.storeDir (toString cfg.site.root))
        "d ${cfg.site.root} 0755 nginx nginx -";
    })
  ]);
}
