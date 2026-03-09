{ ... }:
{
  imports = [
    ./prometheus.nix
    ./prometheus-improvement_it.nix
    ./prometheus-technative.nix
    ./alertmanager-base.nix
    # ./alertmanager-slack.nix  # Uncomment om Slack notificaties in te schakelen
    ./exporters/blackbox.nix
    ./exporters/vulnix.nix
  ];
}

