{ config, lib, pkgs, agenix, ... }:

{
  environment.systemPackages = with pkgs; [
    # Bestaande extensies
    gnomeExtensions.argos
    gnomeExtensions.appindicator
    gnomeExtensions.astra-monitor
    gnomeExtensions.caffeine
    gnomeExtensions.dock-from-dash
    # gnomeExtensions.dash-to-dock  # Verwijderd t.b.v. dash-to-panel
    gnomeExtensions.date-menu-formatter
    gnomeExtensions.gsconnect
    gnomeExtensions.night-light-slider-updated
    gnomeExtensions.power-profile-switcher
    gpaste  # Verplaatst van gnome.gpaste naar top-level
    gnomeExtensions.unite

    # 🔧 Toegevoegde extensies voor DevOps-setup
    dconf
    gnomeExtensions.dash-to-panel
    gnomeExtensions.vitals
    gnomeExtensions.clipboard-indicator
  ];

  # 📌 Extensies automatisch inschakelen via dconf
  programs.dconf.enable = true;

  # Je kunt extensies ook handmatig enablen via dconf settings:
  # Gebruik: dconf write /org/gnome/shell/enabled-extensions "['dash-to-panel@jderose9.github.com', ...]"
  # Of gebruik GNOME Extensions app om ze in te schakelen
}

