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
  services.displayManager.defaultSession = "gnome";
  services.gnome.gnome-settings-daemon.enable = true;
  services.gnome.gnome-keyring.enable = true;  # Voor VPN/WiFi secrets (NetworkManager)
  programs.xwayland.enable = true;

  # ===== XDG Portals =====
  # Voor Wayland screen sharing, file dialogs, etc.
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
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
