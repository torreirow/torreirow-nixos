{ config, pkgs, lib, ... }:

{
  ## SSH client configuratie
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks."*" = {
      addKeysToAgent = "yes";
    };
  };

  ## Use rbw-agent as SSH agent
  home.sessionVariables = {
    SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/rbw/ssh-agent-socket";
  };

  ## GNOME keyring mag géén ssh-agent zijn
  services.gnome-keyring.components = [
    "pkcs11"
    "secrets"
    "crypto"
  ];
}

