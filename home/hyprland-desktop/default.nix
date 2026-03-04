{ lib, pkgs, ... }:

{
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./wofi.nix
    ./mako.nix
    ./hyprlock.nix
    ./hypridle.nix
  ];

  home.packages = with pkgs; [
    grimblast     # native Hyprland screenshots
    wl-clipboard  # clipboard utilities
    wf-recorder   # screen recording
    wlogout       # logout menu
  ];
}
