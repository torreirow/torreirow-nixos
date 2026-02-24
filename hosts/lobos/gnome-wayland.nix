{ config, lib, pkgs, ... }:

# GNOME Desktop + Wayland configuratie voor GNOME 49+
# Bevat fixes voor Qt en Electron apps die geen venster tonen op Wayland

{
  # ===== GNOME Desktop Environment =====
  services.xserver.enable = true;
  services.displayManager.sddm.enable = false;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.displayManager.defaultSession = "gnome";
  services.gnome.gnome-settings-daemon.enable = true;

  # ===== Mutter/Wayland Settings =====
  # Experimental features voor betere Wayland/XWayland compatibility
  services.desktopManager.gnome.extraGSettingsOverrides = ''
    [org/gnome/mutter]
    experimental-features=['scale-monitor-framebuffer', 'xwayland-native-scaling']
    center-new-windows=true
  '';

  # ===== XDG Portals =====
  # Voor Wayland screen sharing, file dialogs, etc.
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
  };

  # ===== Wayland Environment Variables =====
  environment.sessionVariables = {
    # Force Qt apps to use native Wayland (fixes invisible windows on GNOME 49+)
    # Werkt voor: Clementine, mscore/MuseScore, etc.
    QT_QPA_PLATFORM = "wayland";
  };

  environment.variables = {
    # Electron apps (Bitwarden, VSCode, Signal, etc.) Wayland fix for GNOME 49+
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
  };

  # ===== GNOME Packages =====
  environment.gnome.excludePackages = (with pkgs; [
    gnome-photos
    gnome-tour
  ]) ++ (with pkgs.gnome; [
    # gnome-characters
    # gnome-contacts
  ]);

  environment.systemPackages = with pkgs; [
    # GNOME Extensions
    gnomeExtensions.argos
    gnomeExtensions.appindicator
    gnomeExtensions.astra-monitor
    gnomeExtensions.caffeine
    gnomeExtensions.dock-from-dash
    gnomeExtensions.date-menu-formatter
    gnomeExtensions.gsconnect
    gnomeExtensions.night-light-slider-updated
    gnomeExtensions.power-profile-switcher
    gpaste
    gnomeExtensions.unite
    gnomeExtensions.dash-to-panel
    gnomeExtensions.vitals
    gnomeExtensions.clipboard-indicator

    # GNOME tools
    dconf
  ];
}
