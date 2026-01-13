# postfix-kpn-relay.nix
{ config, pkgs, agenix, ... }:

{
  # Postfix configuratie voor KPN SMTP relay
  services.postfix = {
    enable = true;
    
    # Basis configuratie
    hostname = "home.toorren.net"; # Pas aan naar jouw hostname
    
    # SMTP relay configuratie
    relayHost = "smtp.kpn.com";
    relayPort = 587; # STARTTLS port
    
    # Gebruik SASL authenticatie
    setSasl = true;
    
    config = {
      # TLS configuratie voor uitgaande verbindingen
      smtp_use_tls = "yes";
      smtp_sasl_auth_enable = "yes";
      smtp_sasl_security_options = "noanonymous";
      smtp_sasl_password_maps = "hash:/run/agenix/postfix-sasl-password";
      smtp_tls_security_level = "encrypt";
      smtp_tls_CAfile = "/etc/ssl/certs/ca-certificates.crt";
      
      # Optioneel: TLS loglevel voor debugging
      # smtp_tls_loglevel = "1";
      
      # Sender rewriting (optioneel, pas aan indien nodig)
      # sender_canonical_maps = "hash:/etc/postfix/sender_canonical";
    };
  };

  # Agenix configuratie voor credentials
  age.secrets.postfix-sasl-password = {
    file = ./secrets/postfix-sasl-password.age;
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
