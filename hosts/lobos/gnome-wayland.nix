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
  # System-wide Wayland compatibility voor alle applicaties
  environment.sessionVariables = {
    # Qt apps - force native Wayland (fixes invisible windows op GNOME 49+)
    # Werkt voor: Clementine, MuseScore, KDE apps, etc.
    QT_QPA_PLATFORM = "wayland";

    # Mozilla apps - enable native Wayland
    MOZ_ENABLE_WAYLAND = "1";

    # SDL apps/games - prefer Wayland
    SDL_VIDEODRIVER = "wayland";

    # GTK apps - prefer Wayland met X11 fallback
    GDK_BACKEND = "wayland,x11";

    # Clutter apps - use Wayland
    CLUTTER_BACKEND = "wayland";
  };

  environment.variables = {
    # Electron apps (Bitwarden, VSCode, Signal, etc.) - Wayland via Ozone
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";

    # NixOS-specific Electron Wayland hint
    NIXOS_OZONE_WL = "1";

    # Java apps - fix voor tiling/reparenting onder Wayland
    _JAVA_AWT_WM_NONREPARENTING = "1";
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
    gnomeExtensions.unite
    gnomeExtensions.dash-to-panel
    gnomeExtensions.vitals
    # Clipboard: clipboard-history@alexsaveau.dev is handmatig geïnstalleerd en werkt goed

    # GNOME tools
    dconf
    wl-clipboard  # Wayland clipboard tools voor screenshot-to-file script
  ];

  programs.dconf.enable = true;
}
