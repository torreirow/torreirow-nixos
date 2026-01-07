# Voorbeeld configuratie voor Authelia gebruikers
# Kopieer naar je host configuration en pas aan naar wens
#
# BELANGRIJK: Genereer password hashes met:
#   nix-shell -p authelia --run "authelia crypto hash generate argon2 --password 'jouwwachtwoord'"
#
# Of als authelia al geïnstalleerd is:
#   authelia crypto hash generate argon2 --password 'jouwwachtwoord'

{ config, ... }:

{
  # Importeer de authelia-users module
  imports = [
    ./authelia-users.nix
  ];

  services.authelia.users = [
    # Admin gebruiker - volledige toegang tot alle services
    {
      username = "wouter";
      displayname = "Wouter van der Toorren";
      email = "wouter@toorren.net";
      # Vervang met je eigen argon2id hash!
      passwordHash = "***REMOVED***";
      groups = [ "admins" "users" "monitoring" ];
      disabled = false;
    }

    # Monitoring gebruiker - alleen toegang tot monitoring tools
    # {
    #   username = "monitoring";
    #   displayname = "Monitoring User";
    #   email = "monitoring@toorren.net";
    #   passwordHash = "***REMOVED***";
    #   groups = [ "monitoring" ];
    #   disabled = false;
    # }

    # Standaard gebruiker - toegang tot basis applicaties
    # {
    #   username = "user";
    #   displayname = "Regular User";
    #   email = "user@toorren.net";
    #   passwordHash = "***REMOVED***";
    #   groups = [ "users" ];
    #   disabled = false;
    # }
  ];
}

# Groepen en hun toegang (gedefinieerd in authelia.nix access_control):
#
# admins:
#   - Volledige toegang tot alle *.toorren.net subdomeinen
#   - Vereist two-factor authenticatie
#
# monitoring:
#   - Toegang tot grafana.toorren.net
#   - Toegang tot prometheus.toorren.net
#   - Vereist two-factor authenticatie
#
# users:
#   - Toegang tot vaultwarden.toorren.net
#   - Toegang tot paperless.toorren.net
#   - Toegang tot baikal.toorren.net
#   - Vereist two-factor authenticatie
#
# Voeg meer groepen toe door de access_control rules in authelia.nix aan te passen
