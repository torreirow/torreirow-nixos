{ config, lib, pkgs, ... }:

# GNOME Desktop + Wayland configuratie voor GNOME 49+
# Bevat fixes voor Qt en Electron apps die geen venster tonen op Wayland

{
  # ===== GNOME Desktop Environment =====
  services.xserver.enable = true;
  services.displayManager.sddm.enable = false;
  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.wayland = true;
  services.desktopManager.gnome.enable = true;
  # Maak GNOME session beschikbaar in GDM session selector
  services.displayManager.sessionPackages = [ pkgs.gnome-session.sessions ];
  services.gnome.gnome-settings-daemon.enable = true;
  services.gnome.gnome-keyring.enable = true;  # Voor VPN/WiFi secrets (NetworkManager)
  programs.xwayland.enable = true;

  # ===== XDG Portals =====
  # XDG Portal configuratie is verplaatst naar hyprland.nix
  # (inclusief GNOME portal voor compatibiliteit)

  # ===== Mutter Wayland Features =====
  services.desktopManager.gnome.extraGSettingsOverrides = ''
    [org/gnome/mutter]
    experimental-features=['scale-monitor-framebuffer', 'xwayland-native-scaling']
    center-new-windows=true
  '';

  # ===== Qt Apps Wayland Support =====
  # Fix voor Qt apps (Clementine, MuseScore, Strawberry) die geen venster tonen
  environment.sessionVariables = {
    QT_QPA_PLATFORM = "wayland";
  };

  # ===== Electron Apps Wayland Support =====
  # Fix voor Electron apps (Bitwarden, VSCode, Signal) die geen venster tonen
  environment.variables = {
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
    gnomeExtensions.unite
    gnomeExtensions.dash-to-panel
    gnomeExtensions.vitals
    # Clipboard: clipboard-history@alexsaveau.dev is handmatig geïnstalleerd en werkt goed

    # GNOME tools
    dconf
    wl-clipboard  # Wayland clipboard tools voor screenshot-to-file script
    networkmanagerapplet  # GUI voor VPN wachtwoord dialogen
    libsecret  # Voor secret-tool (GNOME Keyring beheer)
  ];

  programs.dconf.enable = true;
}
