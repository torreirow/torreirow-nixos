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
    gnome.gpaste
    gnomeExtensions.unite

    # 🔧 Toegevoegde extensies voor DevOps-setup
    dconf
    gnomeExtensions.dash-to-panel
    gnomeExtensions.vitals
    gnomeExtensions.clipboard-indicator
  ];

  # 📌 Extensies automatisch inschakelen
  gnome = {
    enable = true;
    extraGSettingsOverrides = ''
      [org/gnome/shell]
      enabled-extensions=[
        'dash-to-panel@jderose9.github.com',
        'clipboard-indicator@tudmotu.com',
        'Vitals@CoreCoding.com',
        'argos@pew.worldwidemann.com',
        'appindicatorsupport@rgcjonas.gmail.com',
        'astra-monitor@elhan.io',
        'caffeine@patapon.info',
        'dock-from-dash@hiddenirony.net',
        'date-menu-formatter@marcinjakubowski.github.com',
        'gsconnect@andyholmes.github.io',
        'night-light-slider-updated@reelgiant.com',
        'power-profile-switcher@luisfpaz',
        'gpaste@gnome-shell-extensions.gnome.org',
        'unite@hardpixel.eu'
      ]
    '';
  };
}

