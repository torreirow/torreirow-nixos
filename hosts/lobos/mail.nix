{ config, pkgs, lib, ... }:

{
  # msmtp als sendmail-vervanging voor command line mail versturen via AWS SES
  programs.msmtp = {
    enable = true;
    setSendmail = true;
    extraConfig = ''
      defaults
      tls            on
      tls_trust_file /etc/ssl/certs/ca-certificates.crt

      account        default
      host           email-smtp.eu-central-1.amazonaws.com
      port           587
      auth           on
      from           lobos@toorren.net
      user           AKIAXIOEEMOOS4C73ZCT
      passwordeval   cat /run/secrets/msmtp-password
    '';
  };

  # mailutils voor het 'mail' commando
  environment.systemPackages = with pkgs; [ mailutils ];

  # Agenix secret voor AWS SES SMTP wachtwoord (alleen het wachtwoord, geen username)
  age.secrets.msmtp-password = {
    file = ../../secrets/msmtp-password.age;
    path = "/run/secrets/msmtp-password";
    owner = "wtoorren";
    mode = "0400";
  };
}
