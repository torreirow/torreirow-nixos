# Plasma 6 met Windows-achtige defaults.
#
# De defaults staan in /etc/xdg: KConfig leest die als systeemlaag ónder ~/.config, dus wat
# Maaike zelf instelt wint altijd. Daarom geen plasma-manager (die zou haar keuzes bij elke
# deploy terugzetten).
{ config, lib, pkgs, ... }:

{
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  environment.etc = {
    "xdg/kdeglobals".text = ''
      [General]
      BrowserApplication=firefox.desktop
      TerminalApplication=alacritty
      TerminalService=Alacritty.desktop

      [KDE]
      SingleClick=false
    '';

    # Sneltoetsen zoals in Windows. Win+L en Win+E zijn ook de Plasma-defaults; ze staan
    # hier zodat de afspraak niet afhangt van een toekomstige Plasma-versie.
    "xdg/kglobalshortcutsrc".text = ''
      [ksmserver]
      Lock Session=Meta+L\tScreensaver,Meta+L\tScreensaver,Lock Session

      [services][org.kde.dolphin.desktop]
      _launch=Meta+E

      [services][org.kde.konsole.desktop]
      _launch=none

      [services][Alacritty.desktop]
      _launch=Ctrl+Alt+T

      [services][org.kde.spectacle.desktop]
      RectangularRegionScreenShot=Meta+Shift+S
    '';
  };
}
