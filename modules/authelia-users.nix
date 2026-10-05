{ config, lib, pkgs, ... }:

with lib;

let
  # Gebruikers zonder wachtwoord: dit deel staat leesbaar in Nix (en de store).
  # De argon2id-hashes komen uit agenix en worden bij de start van Authelia erin gezet,
  # zodat ze niet in de publieke repo of de world-readable nix-store staan.
  usersSkeleton = pkgs.writeText "authelia-users-skeleton.json" (builtins.toJSON {
    users = builtins.listToAttrs (map (user: {
      name = user.username;
      value = {
        disabled = user.disabled;
        displayname = user.displayname;
        email = user.email;
        groups = user.groups;
      };
    }) config.services.authelia.users);
  });

  usersDb = "/var/lib/authelia-main/users_database.yml";

  # Hashes-bestand: JSON-object { "<username>": "$argon2id$..." }.
  # Breekt af als een gebruiker geen argon2-hash heeft: liever geen start dan een
  # gebruikersdatabase met een leeg wachtwoord.
  mergeUsers = ''
    hashes=${config.age.secrets.authelia-password-hashes.path}
    missing=$(${pkgs.jq}/bin/jq -r --slurpfile h "$hashes" \
      '.users | keys[] | select(($h[0][.] // "") | startswith("$argon2") | not)' \
      ${usersSkeleton})
    if [ -n "$missing" ]; then
      echo "authelia-users: geen argon2-hash voor: $missing" >&2
      exit 1
    fi
    tmp=$(mktemp ${usersDb}.XXXXXX)
    ${pkgs.jq}/bin/jq --slurpfile h "$hashes" \
      '.users |= with_entries(.value.password = $h[0][.key])' ${usersSkeleton} \
      | ${pkgs.yq}/bin/yq -y '.' > "$tmp"
    chmod 0600 "$tmp"
    # mv vervangt ook de oude store-symlink door een echt bestand
    mv -f "$tmp" ${usersDb}
  '';
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
    description = ''
      Lijst van Authelia gebruikers. De wachtwoord-hashes staan per username in
      secrets/authelia-password-hashes.age. Hash genereren met:
      authelia crypto hash generate argon2 --password 'jouwwachtwoord'
    '';
  };

  config = mkIf (config.services.authelia.users != []) {
    age.secrets.authelia-password-hashes = {
      file = ../secrets/authelia-password-hashes.age;
      path = "/run/agenix/authelia-password-hashes";
      mode = "0400";
      owner = "authelia-main";
      group = "authelia-main";
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/authelia-main 0750 authelia-main authelia-main -"
    ];

    # Vóór de validate-config van de NixOS-module, die het bestand al nodig heeft
    systemd.services.authelia-main = {
      preStart = mkBefore mergeUsers;
      restartTriggers = [ usersSkeleton config.age.secrets.authelia-password-hashes.file ];
    };
  };
}
