{ ... }:
{
  imports = [
    ./prometheus.nix
    ./prometheus-technative.nix
    ./prometheus-torreiro.nix
    # ./alertmanager-base.nix  # Disabled - telegram config gebruikt
    ./alertmanager-telegram.nix  # Telegram notificaties
    # ./alertmanager-slack.nix  # Uncomment om Slack notificaties in te schakelen
    ./exporters/blackbox.nix
    ./exporters/vulnix.nix
  ];
}

