{ config, pkgs, ... }:

{
  # Importeer agenix secrets - zet ze in /run/agenix/ met correcte permissies
  age.secrets = {
    authelia-jwt-secret = {
      file = ../secrets/authelia-jwt-secret.age;
      path = "/run/agenix/authelia-jwt-secret";
      mode = "0440";
      owner = "authelia-main";
      group = "authelia-main";
    };
    authelia-session-secret = {
      file = ../secrets/authelia-session-secret.age;
      path = "/run/agenix/authelia-session-secret";
      mode = "0440";
      owner = "authelia-main";
      group = "authelia-main";
    };
    authelia-storage-encryption-key = {
      file = ../secrets/authelia-storage-encryption-key.age;
      path = "/run/agenix/authelia-storage-encryption-key";
      mode = "0440";
      owner = "authelia-main";
      group = "authelia-main";
    };
    authelia-oidc-hmac-secret = {
      file = ../secrets/authelia-oidc-hmac-secret.age;
      mode = "0440";
      owner = "authelia-main";
      group = "authelia-main";
    };
    authelia-oidc-issuer-private-key = {
      file = ../secrets/authelia-oidc-issuer-private-key.age;
      mode = "0440";
      owner = "authelia-main";
      group = "authelia-main";
    };
  };

  # Zorg dat de authelia-main groep en user bestaan voordat secrets worden aangemaakt
  users.groups.authelia-main = {};

  users.users.authelia-main = {
    isSystemUser = true;
    group = "authelia-main";
    extraGroups = [ "keys" ];
  };

  # Redis voor sessie storage - moet VOOR authelia gestart worden
  services.redis.servers.authelia = {
    enable = true;
    port = 6379;
    bind = "127.0.0.1";
  };

  services.authelia.instances.main = {
    enable = true;
    
    secrets = {
      jwtSecretFile = config.age.secrets.authelia-jwt-secret.path;
      storageEncryptionKeyFile = config.age.secrets.authelia-storage-encryption-key.path;
      oidcHmacSecretFile = config.age.secrets.authelia-oidc-hmac-secret.path;
      oidcIssuerPrivateKeyFile = config.age.secrets.authelia-oidc-issuer-private-key.path;
      # Session secret moet ook als plain text file
      sessionSecretFile = config.age.secrets.authelia-session-secret.path;
    };

    settings = {
      theme = "dark";
      default_2fa_method = "totp";

      server = {
        address = "tcp://127.0.0.1:9091";

        # LET OP -- dit blok VERVANGT de standaardset authz-endpoints; het vult
        # hem niet aan. Alles wat je wilt houden moet hier staan.
        #
        # Gemeten op 2026-09-25: met alleen `mcp` hieronder gaf /api/verify een
        # 404, en daarmee gaven ALLE bestaande vhosts (linny, status-page,
        # pihole, hassio, ...) een 500 -- die gebruiken stuk voor stuk nog het
        # legacy-endpoint. Haal `legacy` hier dus niet weg zonder eerst elke
        # auth_request in modules/ om te bouwen.
        endpoints.authz = {
          # Waar de bestaande vhosts op wijzen: /api/verify
          legacy.implementation = "Legacy";

          # Eigen endpoint voor de MCP-server, op /api/authz/mcp. AuthRequest is
          # de implementatie die bij nginx' auth_request-module hoort. Alleen het
          # Bearer-schema: een MCP-client stuurt een token en volgt géén redirect
          # naar een inlogpagina, dus CookieSession staat er bewust niet bij --
          # die zou een 302 naar het portaal opleveren.
          mcp = {
            implementation = "AuthRequest";
            authn_strategies = [
              {
                name = "HeaderAuthorization";
                schemes = [ "Bearer" ];
              }
            ];
          };
        };
      };

      log = {
        level = "info";
        format = "text";
      };

      totp = {
        disable = false;
        issuer = "toorren.net";
        algorithm = "sha1";
        digits = 6;
        period = 30;
        skew = 1;
      };

      webauthn = {
        disable = false;
        display_name = "Toorren.net";
        attestation_conveyance_preference = "indirect";
        timeout = "60s";
        selection_criteria = {
          user_verification = "preferred";
        };
      };


      authentication_backend = {
        password_reset.disable = false;
        
        file = {
          path = "/var/lib/authelia-main/users_database.yml";
          password = {
            algorithm = "argon2";
            argon2 = {
              variant = "argon2id";
              iterations = 3;
              memory = 65536;
              parallelism = 4;
              key_length = 32;
              salt_length = 16;
            };
          };
        };
      };

      access_control = {
        default_policy = "deny";

        rules = [
          # Authelia zelf is altijd toegankelijk
          {
            domain = "auth.toorren.net";
            policy = "bypass";
          }

          # KPN Modem - bypass voor lokale netwerken, 2FA voor externe toegang
          {
            domain = "kpn.toorren.net";
            policy = "bypass";
            networks = [
              "192.168.0.0/16"
              "10.0.0.0/8"
              "172.16.0.0/12"
              "127.0.0.1/8"
            ];
          }
          {
            domain = "kpn.toorren.net";
            policy = "two_factor";
            subject = [ "group:users" ];
          }

          # Admin groep heeft toegang tot alles met 2FA
          {
            domain = "*.toorren.net";
            policy = "two_factor";
            subject = [
              "group:admins"
            ];
          }

          # Monitoring groep heeft toegang tot monitoring tools
          {
            domain = [
              "grafana.toorren.net"
              "prometheus.toorren.net"
            ];
            policy = "two_factor";
            subject = [
              "group:monitoring"
            ];
          }

          # Users groep heeft toegang tot standaard applicaties
          {
            domain = [
              "docs.toorren.net"
              "contacts.toorren.net"
            ];
            policy = "two_factor";
            subject = [
              "group:users"
            ];
          }

          # Network groep heeft toegang tot netwerk beheer tools
          {
            domain = [
              "wg.toorren.net"
            ];
            policy = "two_factor";
            subject = [
              "group:network"
            ];
          }

          # Publiek toegankelijke services (niet beschermd door Authelia):
          # - vw.toorren.net (Vaultwarden - voor mobiele apps en browser extensies)
          # - adresses.toorren.net (Baikal CalDAV/CardDAV - voor DAV clients)
        ];
      };

      session = {
        # Let op: session.secret wordt via settingsFiles geladen
        # Nieuwe multi-domain configuratie (v4.38.0+)
        cookies = [
          {
            domain = "toorren.net";
            authelia_url = "https://auth.toorren.net";
            default_redirection_url = "https://toorren.net";
            name = "authelia_session";
            same_site = "lax";
            expiration = "1h";
            inactivity = "5m";
          }
        ];

        redis = {
          host = "127.0.0.1";
          port = 6379;
          database_index = 0;
        };
      };

      regulation = {
        max_retries = 3;
        find_time = "2m";
        ban_time = "5m";
      };

      storage = {
        local = {
          path = "/var/lib/authelia-main/db.sqlite3";
        };
      };

      notifier = {
        disable_startup_check = false;

        # SMTP via lokale Postfix (relayed naar AWS SES)
        smtp = {
          address = "smtp://localhost:25";
          timeout = "5s";
          sender = "Authelia <authelia@toorren.net>";
          identifier = "toorren.net";
          subject = "[Authelia] {title}";
          startup_check_address = "wtoorren@toorren.net";
          disable_require_tls = true;  # Localhost heeft geen TLS nodig
          disable_html_emails = false;
        };
      };

      identity_providers = {
        oidc = {
          # SERVER-BREED, raakt dus ook de Wallos-client.
          #
          # Authelia eist PAR zodra een client de scope `authelia.bearer.authz`
          # gebruikt -- gemeten 2026-09-25, validate-config weigert de client
          # anders. Claude deed geen PAR en kreeg "Pushed Authorization Requests
          # are required but this Authorization Request was not made as a Pushed
          # Authorization Request".
          #
          # Deze vlag verschijnt letterlijk in de discovery-metadata. GEMETEN
          # 2026-09-25: op `true` gebruikt Claude alsnog geen PAR -- dezelfde
          # foutmelding -- en brak Wallos er wél op. Blijft dus uit.
          # Zie openspec/changes/add-linny-mcp-oidc/design.md.
          require_pushed_authorization_requests = false;

          cors = {
            endpoints = [ "authorization" "token" "revocation" "introspection" ];
            allowed_origins_from_client_redirect_uris = true;
          };
          clients = [
            {
              client_id = "wallos";
              client_name = "Wallos";
              # Genereer hash met: authelia crypto hash generate argon2 --password '<jouw-secret>'
              # Vervang onderstaande placeholder na het genereren
              client_secret = "$argon2id$v=19$m=65536,t=3,p=4$NGtfEGJ3Ji6O8XBgPIonJQ$DuiJZdWGDta2YnoutWl00NV6Yt2wScOlXdzJ4Np8Kf4";
              public = false;
              authorization_policy = "two_factor";
              redirect_uris = [ "https://subscriptions.toorren.net/index.php" ];
              scopes = [ "openid" "profile" "email" ];
              grant_types = [ "authorization_code" ];
              response_types = [ "code" ];
              response_modes = [ "form_post" "query" "fragment" ];
              token_endpoint_auth_method = "client_secret_post";
              userinfo_signed_response_alg = "none";
              # Onthoud toestemming één maand (M = maand, m = minuut) i.p.v. bij elke login vragen
              consent_mode = "pre-configured";
              pre_configured_consent_duration = "1M";
            }

            # Claude's MCP-connector. Publieke client met PKCE; Claude's dialoog
            # vraagt optioneel om een secret, maar dat is bij PKCE niet nodig.
            #
            # BEWUST GEEN `authelia.bearer.authz`. Die scope trekt een hele reeks
            # eisen mee -- verplicht PAR, alleen form_post, geen andere scopes --
            # en Claude doet geen PAR. Gemeten 2026-09-25, ook niet wanneer de
            # discovery-metadata het als verplicht adverteert. Het token wordt nu
            # gevalideerd door linny-mcp-authz via het introspection-endpoint, en
            # daarvoor gelden die eisen niet.
            {
              client_id = "claude-connector";
              client_name = "Claude MCP connector";
              public = true;
              require_pkce = true;
              pkce_challenge_method = "S256";
              scopes = [ "openid" "profile" "email" "offline_access" ];
              # Claude stuurt `resource=https://linny-mcp.toorren.net` mee
              # (RFC 8707) en Authelia vertaalt dat naar een audience. Zonder
              # deze regel: "Requested audience has not been whitelisted by the
              # OAuth 2.0 Client". Hoort niet bij bearer-authz -- het geldt ook
              # voor een gewone client.
              audience = [ "https://linny-mcp.toorren.net" ];
              grant_types = [ "authorization_code" "refresh_token" ];
              response_types = [ "code" ];
              response_modes = [ "query" "form_post" ];
              consent_mode = "explicit";
              token_endpoint_auth_method = "none";
              authorization_policy = "two_factor";
              # GEMETEN 2026-09-25 uit de authorization request in het
              # nginx-access.log. Niet gokken: documentatie en zoekresultaten
              # noemden pivot.claude.ai/auth/gateway-callback, en dat is het niet.
              redirect_uris = [ "https://claude.ai/api/mcp/auth_callback" ];
            }

            # De tokenvalidator. Praat alleen met het introspection-endpoint en
            # doorloopt zelf nooit een gebruikersflow -- vandaar client_credentials
            # en geen redirect_uris. Vertrouwelijke client: hij moet zich kunnen
            # legitimeren bij introspection.
            {
              client_id = "linny-mcp-authz";
              client_name = "linny-mcp tokenvalidator";
              public = false;
              # Argon2id-hash; het platte geheim staat in
              # secrets/linny-mcp-authz-secret.age en gaat nergens anders heen.
              #
              # BEWUST GOEDKOPE PARAMETERS (m=8192,t=1,p=1 in plaats van de
              # standaard m=65536,t=3,p=4). Gemeten op malandro: met de standaard
              # kostte élke introspection 164 ms, waarvan 163 ms deze hash -- een
              # verzoek zonder client-auth doet er 1 ms over. Die kosten bestaan
              # om zwakke, door mensen gekozen wachtwoorden te beschermen tegen
              # offline kraken. Dit geheim is 72 willekeurige tekens; daar helpt
              # een dure hash niets extra tegen. Zo kan de cache in de validator
              # kort, en blijft een ingetrokken token niet minutenlang bruikbaar.
              client_secret = "$argon2id$v=19$m=8192,t=1,p=1$N8jjWMoAbL5ht7JDuISO9Q$ezP2zOsok/uxM/SRLQ0JAUm3FXLABF55k0J5WR/ItRQ";
              authorization_policy = "one_factor";
              grant_types = [ "client_credentials" ];
              # Leeg, niet [ "openid" ]: Authelia weigert openid bij
              # client_credentials -- er is geen gebruiker om een identiteit van
              # te maken. Introspection vraagt alleen dat de client zich kan
              # legitimeren, geen scope.
              scopes = [ ];
              response_types = [ ];
              redirect_uris = [ ];
            }
          ];
        };
      };
    };
  };

  # Maak de authelia systemd service afhankelijk van redis
  systemd.services.authelia-main = {
    after = [ "redis-authelia.service" ];
    requires = [ "redis-authelia.service" ];
  };

  # Nginx reverse proxy configuratie
  services.nginx = {
    enable = true;
    
    virtualHosts."auth.toorren.net" = {
      forceSSL = true;
      enableACME = true;
      
      locations."/" = {
        proxyPass = "http://127.0.0.1:9091";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header X-Forwarded-Host $http_host;
        '';
      };
    };
  };

  # Firewall
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
