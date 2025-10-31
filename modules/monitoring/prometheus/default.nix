{ ... }:
{
  imports = [
    ./prometheus.nix
    ./alertmanager.nix
    ./exporters/blackbox.nix
  ];
}

