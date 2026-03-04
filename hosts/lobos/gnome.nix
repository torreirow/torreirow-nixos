{ config, lib, pkgs, ... }:

# Minimale GNOME Desktop configuratie
# Geen speciale Wayland tweaks - laat GNOME zelf de defaults bepalen

{
  # ===== GNOME Desktop Environment =====
  services.xserver.enable = true;

  # Use LightDM instead of GDM - it always shows session selector
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.displayManager.lightdm.greeters.gtk.enable = true;

  services.desktopManager.gnome.enable = true;

  # ===== XDG Portals (nodig voor screen sharing, file dialogs, etc.) =====
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
  };

  # ===== GNOME Packages =====
  # Optionele packages die je niet wilt
  environment.gnome.excludePackages = (with pkgs; [
    gnome-photos
    gnome-tour
  ]) ++ (with pkgs.gnome; [
    # gnome-characters
    # gnome-contacts
  ]);

  # GNOME tools en extensions
  environment.systemPackages = with pkgs; [
    # GNOME Extensions
    gnomeExtensions.appindicator
    gnomeExtensions.caffeine
    gnomeExtensions.dash-to-panel
    gnomeExtensions.vitals

    # GNOME tools
    dconf
    wl-clipboard  # Wayland clipboard tools
  ];

  programs.dconf.enable = true;
}
