# postfix-aws-ses-relay.nix
#
# AWS SES SMTP relay configuratie
#
# Vereist secrets bestand format in /run/agenix/postfix-sasl-password:
# [email-smtp.REGION.amazonaws.com]:587 SMTP_USERNAME:SMTP_PASSWORD
#
# Voorbeeld:
# [email-smtp.eu-west-1.amazonaws.com]:587 AKIAIOSFODNN7EXAMPLE:wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
#
# SMTP credentials verkrijgen:
# 1. Ga naar AWS Console > SES > SMTP Settings
# 2. Klik "Create SMTP Credentials"
# 3. Download de credentials (username + password)
#
# Encrypt het bestand met agenix:
# echo '[email-smtp.REGION.amazonaws.com]:587 USERNAME:PASSWORD' > postfix-sasl-password.txt
# agenix -e secrets/postfix-sasl-password.age
#
{ config, pkgs, lib, ... }:

let
  # Configureerbare opties
  awsRegion = "eu-central-1"; # Pas aan naar jouw AWS regio
  relayHost = "email-smtp.${awsRegion}.amazonaws.com";
in
{
  # Postfix configuratie voor AWS SES SMTP relay
  services.postfix = {
    enable = true;

    # Basis configuratie
    hostname = "toorren.net"; # Pas aan naar jouw hostname

    # AWS SES relay configuratie
    relayHost = relayHost;
    relayPort = 587; # STARTTLS port (AWS SES ondersteunt 25, 587, 2587)
    
    # Gebruik SASL authenticatie
    setSasl = true;

    config = {
      # TLS configuratie voor uitgaande verbindingen naar AWS SES
      smtp_use_tls = "yes";
      smtp_tls_security_level = "encrypt"; # Verplicht TLS voor AWS SES
      smtp_tls_CAfile = "/etc/ssl/certs/ca-certificates.crt";
      smtp_tls_note_starttls_offer = "yes";

      # SASL authenticatie (AWS SES)
      smtp_sasl_auth_enable = "yes";
      smtp_sasl_security_options = "noanonymous";
      smtp_sasl_password_maps = "hash:/run/agenix/postfix-sasl-password";
      smtp_sasl_mechanism_filter = "plain,login"; # AWS SES ondersteunt alleen PLAIN en LOGIN

      # Optioneel: TLS loglevel voor debugging (uncomment indien nodig)
      # smtp_tls_loglevel = "1";

      # AWS SES specifieke instellingen
      # Beperk message size tot AWS SES limiet (10 MB voor raw message, 40 MB na base64 encoding)
      message_size_limit = "10485760"; # 10 MB

      # Sender rewriting (optioneel, pas aan indien nodig)
      # Nuttig als je mail wilt versturen vanuit verschillende adressen
      # sender_canonical_maps = "hash:/etc/postfix/sender_canonical";

      # Fallback relay (optioneel)
      # smtp_fallback_relay = "";
    };
  };

  # Agenix configuratie voor AWS SES SMTP credentials
  # Het .age bestand moet het volgende formaat hebben (ongeëncrypt):
  # [email-smtp.REGION.amazonaws.com]:587 SMTP_USERNAME:SMTP_PASSWORD
  age.secrets.postfix-sasl-password = {
    file = ../secrets/postfix-sasl-password.age;
    path = "/run/agenix/postfix-sasl-password";
    owner = "postfix";
    group = "postfix";
    mode = "0400";
  };

  # Systemd service om postmap te draaien na het decrypten van secrets
  systemd.services.postfix-sasl-setup = {
    description = "Setup Postfix SASL password database";
    before = [ "postfix.service" ];
    after = [ "agenix.service" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    
    script = ''
      # Wacht tot het secret bestand beschikbaar is
      while [ ! -f /run/agenix/postfix-sasl-password ]; do
        sleep 0.1
      done
      
      # Maak postmap database
      ${pkgs.postfix}/bin/postmap /run/agenix/postfix-sasl-password
      
      # Zet juiste permissies
      chown postfix:postfix /run/agenix/postfix-sasl-password.db
      chmod 0400 /run/agenix/postfix-sasl-password.db
    '';
  };

  # Zorg dat postfix na de SASL setup start
  systemd.services.postfix = {
    after = [ "postfix-sasl-setup.service" ];
    requires = [ "postfix-sasl-setup.service" ];
  };
}
