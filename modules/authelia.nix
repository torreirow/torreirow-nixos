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
            domain = "edge.toorren.net";
            policy = "bypass";
            networks = [
              "192.168.0.0/16"
              "10.0.0.0/8"
              "172.16.0.0/12"
              "127.0.0.1/8"
            ];
          }
          {
            domain = "edge.toorren.net";
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
              grant_types = [ "refresh_token" "authorization_code" ];
              response_types = [ "code" ];
              response_modes = [ "form_post" "query" "fragment" ];
              userinfo_signed_response_alg = "none";
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
