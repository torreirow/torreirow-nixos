{ config, pkgs, lib, ... }:

{
  # Agenix secret for Vikunja environment variables (database password, etc.)
  age.secrets.vikunja-env = {
    file = ../secrets/vikunja-env.age;
    path = "/run/agenix/vikunja-env";
    mode = "0400";
  };

  # Vikunja - Open source todo/task management
  services.vikunja = {
    enable = true;

    # Bind to localhost only (accessed via nginx reverse proxy)
    address = "127.0.0.1";
    port = 8093;

    # Frontend configuration
    frontendScheme = "https";
    frontendHostname = "tasks.toorren.net";

    # Load secrets from agenix
    environmentFiles = [
      config.age.secrets.vikunja-env.path
    ];

    # Vikunja configuration
    settings = {
      # Service configuration
      service = {
        publicurl = "https://tasks.toorren.net";
        enableregistration = false;  # Only admin can create users
        enableemailreminders = true;
        timezone = "Europe/Amsterdam";
      };

      # Database configuration (PostgreSQL on localhost)
      database = {
        type = "postgres";
        host = "localhost";
        database = "vikunja";
        user = "vikunja";
        # Password loaded from environment file: VIKUNJA_DATABASE_PASSWORD
        sslmode = "disable";  # Local connection, no SSL needed
      };

      # SMTP configuration (Postfix on localhost)
      mailer = {
        enabled = true;
        host = "localhost";
        port = 25;
        authtype = "plain";
        fromemail = "vikunja@toorren.net";
        # No auth needed for localhost postfix
        forcessl = false;
        skiptlsverify = true;
      };

      # Disable external auth providers
      auth = {
        local = {
          enabled = true;
        };
        openid = {
          enabled = false;
        };
      };
    };
  };

  # PostgreSQL: Create database and user
  services.postgresql = {
    ensureDatabases = lib.mkAfter [ "vikunja" ];
    ensureUsers = lib.mkAfter [
      {
        name = "vikunja";
        ensureDBOwnership = true;
      }
    ];
  };

  # Set vikunja user password after PostgreSQL starts
  systemd.services.postgres-set-vikunja-password = {
    description = "Set PostgreSQL password for vikunja";
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
    };

    script = ''
      # Only set password if VIKUNJA_DATABASE_PASSWORD is set in environment file
      if [ -f ${config.age.secrets.vikunja-env.path} ]; then
        source ${config.age.secrets.vikunja-env.path}
        if [ -n "$VIKUNJA_DATABASE_PASSWORD" ]; then
          /run/current-system/sw/bin/psql -d postgres <<EOF
            ALTER USER vikunja PASSWORD '$VIKUNJA_DATABASE_PASSWORD';
EOF
        fi
      fi
    '';
  };

  # Nginx reverse proxy with Authelia authentication
  services.nginx.virtualHosts."tasks.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";

    locations."/" = {
      proxyPass = "http://127.0.0.1:8093";
      proxyWebsockets = true;
      extraConfig = ''
        auth_request /authelia;
        error_page 401 = @authelia_portal;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };

    # Authelia redirect named location
    locations."@authelia_portal" = {
      extraConfig = ''
        return 302 https://auth.toorren.net/?rd=$scheme://$http_host$request_uri;
      '';
    };

    # Authelia authentication endpoint
    locations."/authelia" = {
      proxyPass = "http://127.0.0.1:9091/api/verify";
      extraConfig = ''
        internal;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header Content-Length "";
        proxy_pass_request_body off;
      '';
    };
  };
}
