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
  # System-wide Wayland compatibility met pragmatische fallbacks
  # Principe: PREFER Wayland waar mogelijk, maar ALLOW XWayland fallback
  environment.sessionVariables = {
    # Qt apps - prefer Wayland met XCB (X11) fallback
    # Dit lost invisible window bugs op zonder apps te breken
    # Werkt voor: Clementine, MuseScore, EN Zoom, OnlyOffice, etc.
    QT_QPA_PLATFORM = "wayland;xcb";  # Fallback naar XWayland als Wayland faalt

    # Mozilla apps - enable native Wayland (werkt goed)
    MOZ_ENABLE_WAYLAND = "1";

    # SDL apps/games - prefer Wayland met X11 fallback
    SDL_VIDEODRIVER = "wayland,x11";

    # GTK apps - prefer X11 fallback voor sandboxed apps (OnlyOffice, Flatpaks)
    # Veel GTK apps in sandboxes hebben geen Wayland socket toegang
    GDK_BACKEND = "x11,wayland";

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
