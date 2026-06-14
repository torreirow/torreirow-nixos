{ pkgs, ... }:

{
  programs.hyprland.enable = true;
  programs.hyprland.xwayland.enable = true;

  # UWSM beheert de Hyprland sessie via systemd; units moeten beschikbaar zijn in /etc/systemd/user/
  systemd.packages = [ pkgs.uwsm ];

  # Hyprlock PAM service: alleen wachtwoord, geen vingerafdruk (fprintd veroorzaakt lange wachttijd)
  security.pam.services.hyprlock = {
    fprintAuth = false;
  };

  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];

  environment.systemPackages = with pkgs; [
    uwsm
    hyprpaper
    hyprlock
    hypridle
    waybar
    rofi
    mako
    kitty
    catppuccin-hyprland
    catppuccin-gtk
    catppuccin-cursors
    grimblast
  ];
}
