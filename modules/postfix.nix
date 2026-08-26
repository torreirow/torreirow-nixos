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

    # NixOS 25.11 configuratie formaat
    settings.main = {
      # Basis configuratie
      myhostname = "malandro.toorren.net";
      mydomain = "toorren.net";
      myorigin = "$mydomain";

      # Postfix is alleen een relay, geen lokale mail ontvanger
      mydestination = ""; # Lege string = geen lokale delivery
      local_recipient_maps = ""; # Disable lokale recipient checks

      # Vertrouw lokale Docker container subnets voor relay
      mynetworks = [ "127.0.0.0/8" "[::1]/128" "172.17.0.0/16" "172.18.0.0/16" "172.19.0.0/16" "192.168.2.67/32" ];


      # AWS SES relay configuratie (host:port formaat met brackets voor SASL)
      relayhost = ["[${relayHost}]:587"]; # Brackets matchen SASL password map formaat

      # TLS configuratie voor uitgaande verbindingen naar AWS SES
      smtp_tls_security_level = "encrypt"; # Verplicht TLS voor AWS SES
      smtp_tls_CAfile = "/etc/ssl/certs/ca-certificates.crt";
      smtp_tls_note_starttls_offer = "yes";

      # SASL authenticatie (AWS SES)
      smtp_sasl_auth_enable = "yes";
      smtp_sasl_security_options = "noanonymous";
      smtp_sasl_password_maps = "hash:/etc/postfix/sasl_passwd";
      smtp_sasl_mechanism_filter = "plain,login"; # AWS SES ondersteunt alleen PLAIN en LOGIN

      # Optioneel: TLS loglevel voor debugging (uncomment indien nodig)
      # smtp_tls_loglevel = "1";

      # AWS SES specifieke instellingen
      # Beperk message size tot AWS SES limiet (10 MB voor raw message, 40 MB na base64 encoding)
      message_size_limit = 10485760; # 10 MB

      # Sender rewriting - herschrijf @malandro naar @toorren.net
      sender_canonical_maps = "regexp:/etc/postfix/sender_canonical";
      smtp_header_checks = "regexp:/etc/postfix/header_checks";
    };

    # Sender canonical maps - herschrijf lokale adressen naar toorren.net
    mapFiles."sender_canonical" = pkgs.writeText "sender_canonical" ''
      /@malandro$/ wtoorren@toorren.net
    '';

    # Header checks - herschrijf From header
    mapFiles."header_checks" = pkgs.writeText "header_checks" ''
      /^From:(.*)@malandro/ REPLACE From:''${1}@toorren.net
    '';
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
    # Wacht op de juiste mount units (agenix.service bestaat niet!)
    # postmap vereist /etc/postfix/main.cf (aangemaakt door postfix-setup.service)
    after = [ "run-keys.mount" "run-agenix.d.mount" "postfix-setup.service" ];
    requires = [ "run-keys.mount" "run-agenix.d.mount" ];
    wantedBy = [ "multi-user.target" ];
    partOf = [ "postfix.service" ];  # Herstart samen met postfix

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
    };

    script = ''
      # Wacht tot het secret bestand beschikbaar is (met timeout)
      MAX_WAIT=30  # 30 seconden max
      COUNTER=0
      while [ ! -f /run/agenix/postfix-sasl-password ]; do
        sleep 0.1
        COUNTER=$((COUNTER + 1))
        if [ $COUNTER -gt $((MAX_WAIT * 10)) ]; then
          echo "ERROR: Timeout waiting for /run/agenix/postfix-sasl-password"
          exit 1
        fi
      done

      # Extra check: verify symlink target is readable
      if [ ! -r /run/agenix/postfix-sasl-password ]; then
        echo "ERROR: /run/agenix/postfix-sasl-password exists but is not readable"
        exit 1
      fi


      # Kopieer het secret bestand naar /etc/postfix/
      cp /run/agenix/postfix-sasl-password /etc/postfix/sasl_passwd
      chown root:root /etc/postfix/sasl_passwd
      chmod 0600 /etc/postfix/sasl_passwd

      # Maak postmap database in /etc/postfix/
      ${pkgs.postfix}/bin/postmap /etc/postfix/sasl_passwd

      # Zet juiste permissies voor de database
      chown root:root /etc/postfix/sasl_passwd.db
      chmod 0600 /etc/postfix/sasl_passwd.db
    '';
  };

  # Zorg dat postfix na de SASL setup start en altijd de database opnieuw aanmaakt
  systemd.services.postfix = {
    after = [ "postfix-sasl-setup.service" ];
    requires = [ "postfix-sasl-setup.service" ];

    # Run SASL setup script before starting/restarting postfix
    serviceConfig.ExecStartPre = [
      # Wacht op agenix secret
      ''+${pkgs.bash}/bin/bash -c 'while [ ! -f /run/agenix/postfix-sasl-password ]; do sleep 0.1; done' ''
      # Setup SASL database
      "+${pkgs.bash}/bin/bash -c 'cp /run/agenix/postfix-sasl-password /etc/postfix/sasl_passwd && chown root:root /etc/postfix/sasl_passwd && chmod 0600 /etc/postfix/sasl_passwd && ${pkgs.postfix}/bin/postmap /etc/postfix/sasl_passwd && chown root:root /etc/postfix/sasl_passwd.db && chmod 0600 /etc/postfix/sasl_passwd.db'"
    ];
  };

  # Sta SMTP-relay toe vanaf bobadela1 (Nextcloud AIO) - alleen die ene host
  networking.firewall.extraCommands = ''
    iptables -I nixos-fw 1 -p tcp -s 192.168.2.67 --dport 25 -j nixos-fw-accept
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D nixos-fw -p tcp -s 192.168.2.67 --dport 25 -j nixos-fw-accept || true
  '';
}
