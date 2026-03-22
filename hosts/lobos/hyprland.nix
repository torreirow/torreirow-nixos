{ config, pkgs, ... }:

{
  # Enable Hyprland with UWSM support
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  # XDG Desktop Portal configuration for Hyprland
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
    config = {
      hyprland.default = ["hyprland" "gtk"];
      gnome.default = ["gnome" "gtk"];
    };
  };

  # Core Hyprland system packages
  environment.systemPackages = with pkgs; [
    # Wayland essentials
    wl-clipboard
    wl-clip-persist

    # Screenshot tools
    grim
    slurp

    # Brightness control
    brightnessctl

    # Media control
    playerctl

    # Polkit agent for authentication
    polkit_gnome
  ];

  # Environment variables for Wayland apps
  environment.sessionVariables = {
    # Electron apps (same as GNOME config)
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    NIXOS_OZONE_WL = "1";
  };

  # Enable polkit for authentication dialogs
  security.polkit.enable = true;

  # GNOME Keyring for credential storage (works with Hyprland)
  services.gnome.gnome-keyring.enable = true;
}
