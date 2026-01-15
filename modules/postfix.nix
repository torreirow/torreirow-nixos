{ pkgs, lib, config, ... }:

{
  ########################################
  # CLI mail tools
  ########################################
  environment.systemPackages = with pkgs; [
    mailutils
  ];

  ########################################
  # EXPLICIET: géén msmtp (voorkomt wrapper-conflict)
  ########################################
  programs.msmtp.enable = false;

  ########################################
  # Agenix secret (SMTP SASL credentials)
  ########################################
  age.secrets.postfix-sasl-password = {
    file  = ../secrets/postfix-sasl-password.age;
    owner = "postfix";
    group = "postfix";
    mode  = "0600";
  };

  ########################################
  # Postfix (relay-only, idiomatisch)
  ########################################
  services.postfix = {
    enable = true;

    # géén submission daemon nodig
    enableSubmission = false;

    ####################################
    # main.cf (via settings.main)
    ####################################
    settings.main = {
      # KPN SMTP relay
      relayhost = [ "smtp.kpnmail.nl:587" ];

      # Identiteit
      myhostname = "mail.toorren.net";
      mydomain   = "toorren.net";
      myorigin   = "toorren.net";

      # Alleen lokaal mail accepteren
      inet_interfaces = "loopback-only";
      mydestination  = [ "localhost" ];
      mynetworks     = [ "127.0.0.0/8" ];

      ##################################
      # SASL authenticatie
      ##################################
      smtp_sasl_auth_enable = "yes";
      smtp_sasl_mechanism_filter = [ "plain" "login" ];
      smtp_sasl_password_maps =
        "hash:/var/lib/postfix/sasl_passwd";
      smtp_sasl_security_options = "noanonymous";

      ##################################
      # TLS (KPN / Postfix ≥3.6 correct)
      ##################################
      smtp_tls_security_level = "encrypt";
      smtp_tls_protocols = ">=TLSv1.2";
      smtp_tls_mandatory_protocols = ">=TLSv1.2";
      smtp_tls_CAfile = "/etc/ssl/certs/ca-certificates.crt";
      smtp_tls_loglevel = "1";

      ##################################
      # Sender rewriting
      ##################################
      sender_canonical_maps =
        "hash:/etc/postfix/sender_canonical";
      sender_canonical_classes =
        [ "envelope_sender" ];
    };

    ####################################
    # Canonical map (Nix-native)
    ####################################
    mapFiles.sender_canonical =
      pkgs.writeText "sender_canonical" ''
        @mail.toorren.net       @toorren.net
        root@mail.toorren.net   root@toorren.net
      '';
  };

  ########################################
  # SASL setup service (runtime only)
  ########################################
  systemd.services.postfix-setup-sasl = {
    description = "Setup Postfix SASL credentials";
    wantedBy = [ "postfix.service" ];
    before   = [ "postfix.service" ];

    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };

    script = ''
      set -e

      SECRET="${config.age.secrets.postfix-sasl-password.path}"
      TARGET="/var/lib/postfix/sasl_passwd"

      if [ ! -f "$SECRET" ]; then
        echo "Missing SASL secret: $SECRET"
        exit 1
      fi

      install -d -m 750 -o postfix -g postfix /var/lib/postfix
      install -m 600 -o postfix -g postfix "$SECRET" "$TARGET"

      ${pkgs.postfix}/bin/postmap "$TARGET"
    '';
  };
}

