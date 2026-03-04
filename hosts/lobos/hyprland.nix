{ config, lib, pkgs, ... }:

{
  # Enable Hyprland window manager
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;  # Enable XWayland for legacy apps
  };

  # XDG Portals for Hyprland (screen sharing, file pickers)
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk  # For GTK file pickers
    ];
  };

  # Essential Hyprland system packages
  environment.systemPackages = with pkgs; [
    # Status bar and launcher
    waybar
    wofi

    # Notification daemon
    mako

    # Native Hyprland tools
    grimblast         # Screenshot helper
    hyprpaper         # Wallpaper daemon
    hyprlock          # Screen locker
    hypridle          # Idle management

    # Clipboard
    wl-clipboard

    # Screen recording
    wf-recorder

    # Network manager applet (for waybar tray)
    networkmanagerapplet

    # Volume control (for waybar)
    pavucontrol

    # Brightness control
    brightnessctl

    # Polkit agent (for authentication dialogs)
    polkit_gnome

    # Logout menu
    wlogout
  ];

  # Security: enable polkit
  security.polkit.enable = true;

  # GDM will automatically detect both GNOME and Hyprland sessions
  # No additional configuration needed - both will appear in session selector
}
