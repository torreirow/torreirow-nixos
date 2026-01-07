{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.authelia.instances.main;

  # Formatteer gebruikers voor YAML
  formatUsers = users:
    builtins.listToAttrs (map (user: {
      name = user.username;
      value = {
        disabled = user.disabled or false;
        displayname = user.displayname;
        password = user.passwordHash;
        email = user.email;
        groups = user.groups or [];
      };
    }) users);

  # Genereer de users_database.yml
  usersConfig = {
    users = formatUsers config.services.authelia.users;
  };

  usersFile = pkgs.writeText "users_database.yml" (builtins.toJSON usersConfig);

in
{
  options.services.authelia.users = mkOption {
    type = types.listOf (types.submodule {
      options = {
        username = mkOption {
          type = types.str;
          description = "Username voor login";
        };

        displayname = mkOption {
          type = types.str;
          description = "Volledige naam van de gebruiker";
        };

        email = mkOption {
          type = types.str;
          description = "Email adres voor notificaties en password resets";
        };

        passwordHash = mkOption {
          type = types.str;
          description = ''
            Argon2id password hash. Genereer met:
            authelia crypto hash generate argon2 --password 'jouwwachtwoord'
          '';
        };

        groups = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Groepen waarvan deze gebruiker lid is";
        };

        disabled = mkOption {
          type = types.bool;
          default = false;
          description = "Of dit account uitgeschakeld is";
        };
      };
    });
    default = [];
    description = "Lijst van Authelia gebruikers";
  };

  config = mkIf (config.services.authelia.users != []) {
    # Maak de users database file aan met systemd tmpfiles
    systemd.tmpfiles.rules = [
      "d /var/lib/authelia-main 0750 authelia-main authelia-main -"
      "L+ /var/lib/authelia-main/users_database.yml - - - - ${pkgs.runCommand "users_database.yml" {
        buildInputs = [ pkgs.yq ];
      } ''
        # Converteer JSON naar YAML voor betere leesbaarheid
        echo '${builtins.toJSON usersConfig}' | yq -y '.' > $out
      ''}"
    ];

    # Zorg dat de file wordt herladen als de configuratie verandert
    systemd.services.authelia-main = {
      restartTriggers = [ usersFile ];
    };
  };
}
