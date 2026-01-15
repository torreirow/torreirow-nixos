{ config, pkgs, lib, agenix, ... }:

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
    GSM_SKIP_SSH_AGENT_WORKAROUND = "1";  # Prevent gnome-session from starting SSH agent
  };

  # Agenix secrets for SSH host configurations
  # These are processed at activation time (not evaluation time)
  programs.ssh-config-hosts.agenixSecrets = [{
    name = "customer-prod";
    path = "/run/secrets/ssh-hosts-customer-prod";
  }];
}

