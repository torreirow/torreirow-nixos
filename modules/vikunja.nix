{ config, pkgs, lib, ... }:

{
  # Agenix secret for Vikunja environment variables (database password, etc.)
  age.secrets.vikunja-env = {
    file = ../secrets/vikunja-env.age;
    path = "/run/agenix/vikunja-env";
    mode = "0444";  # World-readable (needed for DynamicUser systemd service)
    # No owner specified - vikunja service will have access via systemd
  };

  # Separate secret for postgres to read (database password setup)
  age.secrets.vikunja-db-password = {
    file = ../secrets/vikunja-env.age;
    owner = "postgres";
    mode = "0400";
  };

  # Vikunja - Open source todo/task management
  services.vikunja = {
    enable = true;

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
        interface = lib.mkForce "127.0.0.1:8093";  # Bind to localhost only (accessed via nginx reverse proxy)
        publicurl = lib.mkForce "https://tasks.toorren.net";
        enableregistration = lib.mkForce false;  # Only admin can create users
        enableemailreminders = lib.mkForce true;
        timezone = lib.mkForce "Europe/Amsterdam";
      };

      # Database configuration (PostgreSQL on localhost)
      database = {
        type = lib.mkForce "postgres";
        host = lib.mkForce "localhost";
        database = lib.mkForce "vikunja";
        user = lib.mkForce "vikunja";
        # Password loaded from environment file: VIKUNJA_DATABASE_PASSWORD
        sslmode = lib.mkForce "disable";  # Local connection, no SSL needed
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
          enabled = true;
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
      if [ -f ${config.age.secrets.vikunja-db-password.path} ]; then
        source ${config.age.secrets.vikunja-db-password.path}
        if [ -n "$VIKUNJA_DATABASE_PASSWORD" ]; then
          /run/current-system/sw/bin/psql -d postgres <<EOF
            ALTER USER vikunja PASSWORD '$VIKUNJA_DATABASE_PASSWORD';
EOF
        fi
      fi
    '';
  };

  # Nginx reverse proxy (TEMPORARILY WITHOUT AUTHELIA FOR TESTING)
  services.nginx.virtualHosts."tasks.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";

    locations."/" = {
      proxyPass = "http://127.0.0.1:8093";
      proxyWebsockets = true;
      extraConfig = ''
        client_max_body_size 20M;
      '';
    };
  };
}
