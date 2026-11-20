# tmux-agent-wizard (taw): één popup met alle sessies en coding agents, met per
# agent de status (blocked/error/working/done/idle). Zie pkgs/tmux-agent-wizard.
#
# Toetsen, bovenop de prefix uit home/tmux.nix (C-a lokaal, C-b over SSH):
#   prefix + A  popup met de hele boom (Tab = volgende die jou nodig heeft)
#   prefix + O  spring direct naar de agent die wacht (nog een keer = de volgende)
#
# Alleen deze machine: geen [machines] in config.toml, dus geen ssh-verkeer.
{ pkgs, lib, ... }:

let
  wizard = pkgs.callPackage ../../pkgs/tmux-agent-wizard { };
in
{
  # taw ook buiten tmux bruikbaar (taw agent list, taw session restore, ...).
  home.packages = [ wizard.taw ];

  programs.tmux.plugins = [
    {
      plugin = wizard.plugin;
      extraConfig = ''
        # De binary komt uit de Nix-store; de eigen download van de plugin staat uit.
        set -g @agent-wizard-bin '${wizard.taw}/bin/taw'
        set -g @agent-wizard-auto-install off

        # prefix + A opent de popup, prefix + O gaat naar de agent die wacht
        # (de upstream-standaard; mipmips V/J gebruiken we niet).
        set -g @agent-wizard 'A'
        set -g @agent-wizard-notification-key 'O'
      '';
    }
  ];

  programs.tmux.extraConfig = lib.mkAfter ''
    # Teller op de statusregel: ⏸1 ⏵3 ✓2 (blocked, working, done). Leeg zonder agents.
    set -ga status-right ' #[fg=#ebdbb2,bg=#3c3836] #{@agent_wizard_status} #[fg=#ebdbb2,bg=#282828]'
  '';
}
