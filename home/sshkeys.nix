{ config, pkgs, lib, ... }:

let
  # Pas deze lijst aan
  sshKeys = [
    "/home/wtoorren/.ssh/improvement-it-wtoorren"
    "/home/wtoorren/.ssh/toorren-lobos-ed25519"
  ];
in
{
  programs.ssh = {
    enable = true;
    startAgent = true;

    extraConfig = ''
      Host *
        IdentitiesOnly yes
    '';
  };

  # Zorg dat GNOME keyring geen SSH-agent speelt
  services.gnome-keyring.components = [
    "pkcs11"
    "secrets"
    "crypto"
  ];

  # Service die de door jou gekozen keys laadt
  systemd.user.services."hm-ssh-add" = {
    Unit = {
      Description = "Add selected SSH keys to Home-Manager ssh-agent";
      After = [ "ssh-agent.service" ];
      Wants = [ "ssh-agent.service" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = lib.concatStringsSep " " (
        [ "${pkgs.openssh}/bin/ssh-add" ] ++ sshKeys
      );
      Environment = {
        SSH_AUTH_SOCK = "%t/ssh-agent";
      };
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}

