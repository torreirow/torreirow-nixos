{ config, pkgs, lib, agenix, ... }:

{
  age.secrets.postgresql-password = {
    file = ../secrets/postgresql-password.age;
    owner = "postgres";
  };

  age.secrets.postgresql-admin-password = {
    file = ../secrets/postgresql-admin-password.age;
    owner = "postgres";
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;

    settings = {
      password_encryption = "scram-sha-256";
    };

    ensureDatabases = [ "postgres" "crowdsec"];

    ensureUsers = [
      {
        name = "crowdsec";
        ensureDBOwnership = true;
      }
    ];

    initialScript = pkgs.writeText "init.sql" ''
      \set postgres_pass `cat ${config.age.secrets.postgresql-password.path}`

      ALTER USER postgres PASSWORD :'postgres_pass';
    '';
  };

	systemd.tmpfiles.rules = [
		"d /run/keys 0755 root root -"
		"d /run/keys/wouter 0750 postgres postgres -"
  ];

  users.users.postgres.extraGroups = [ "keys" ];

  age.secrets.crowdsec-postgres-password = {
    file = ../secrets/crowdsec-postgres-password.age;
    owner = "postgres";
  };

systemd.services.postgres-set-crowdsec-password = {
  description = "Set PostgreSQL password for crowdsec";
  after = [ "postgresql.service" ];
  requires = [ "postgresql.service" ];
  wantedBy = [ "multi-user.target" ];

  serviceConfig = {
    Type = "oneshot";
    User = "postgres";
  };

  script = ''
    /run/current-system/sw/bin/psql -d postgres <<'EOF'
      \set pw `cat ${config.age.secrets.crowdsec-postgres-password.path}`
      ALTER USER crowdsec PASSWORD :'pw';
    EOF
  '';
};


}

