{ config, pkgs, lib, ... }:

let
  sshKeys = [
    "/home/wtoorren/.ssh/improvement-it-wtoorren"
    "/home/wtoorren/.ssh/toorren-lobos-ed25519"
  ];
in
{
  ## SSH client configuratie
  programs.ssh = {
  enable = true;
  enableDefaultConfig = false;

  matchBlocks."*" = {
    identitiesOnly = true;
    addKeysToAgent = "yes";
  };
};



  ## Gebruik Home Manager ssh-agent
  services.ssh-agent.enable = true;

  ## GNOME keyring mag géén ssh-agent zijn
  services.gnome-keyring.components = [
    "pkcs11"
    "secrets"
    "crypto"
  ];

  ## Keys automatisch toevoegen aan de HM ssh-agent
  #systemd.user.services.hm-ssh-add = {
  #  Unit = {
  #    Description = "Add selected SSH keys to Home-Manager ssh-agent";
  #    After = [ "ssh-agent.service" ];
  #    Wants = [ "ssh-agent.service" ];
  #  };

  #  Service = {
  #    Type = "oneshot";
  #    ExecStart = lib.concatStringsSep " " (
  #      [ "${pkgs.openssh}/bin/ssh-add" ] ++ sshKeys
  #    );
  #    Environment = [
  #      "SSH_AUTH_SOCK=%t/ssh-agent"
  #    ];
  #  };

  #  Install = {
  #    WantedBy = [ "default.target" ];
  #  };
  #};
}

