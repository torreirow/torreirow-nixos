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
}
