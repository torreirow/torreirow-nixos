{ config, pkgs, ... }:

{
  imports = [
    ./hyprland-config.nix
    ./waybar.nix
    ./rofi.nix
    ./theme.nix
    ./swaylock.nix
    ./dunst.nix
  ];

  # Disable dconf (GNOME settings) for Hyprland-only setup
  dconf.enable = false;
}
