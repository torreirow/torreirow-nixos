{ pkgs, unstable, ... }:

{
  programs.hyprland.enable = true;
  programs.hyprland.xwayland.enable = true;
  programs.hyprland.withUWSM = true;

  # UWSM beheert de Hyprland sessie via systemd; units moeten beschikbaar zijn in /etc/systemd/user/
  systemd.packages = [ pkgs.uwsm ];

  # Hyprlock PAM service: alleen wachtwoord. Vingerafdruk loopt via hyprlock's eigen D-Bus-pad
  # (auth.fingerprint in home/hyprland/hyprlock.nix), parallel aan PAM. pam_fprintd hier blijft
  # bewust uit: dat blokkeert sequentieel tot vinger of timeout (~30s) vóór het wachtwoord telt.
  security.pam.services.hyprlock = {
    fprintAuth = false;
  };

  xdg.portal = {
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland pkgs.xdg-desktop-portal-gtk ];
    config = {
      common.default = [ "gtk" ];
      hyprland.default = [ "hyprland" "gtk" ];
    };
  };

  services.power-profiles-daemon.enable = true;

  environment.systemPackages = with pkgs; [
    uwsm
    hyprlock
    hypridle
    hyprsunset
    hyprshot
    hyprpicker
    rofi
    waybar
    kitty
    adw-gtk3
    adwaita-icon-theme
    papirus-icon-theme
    grimblast
    brightnessctl
    playerctl
    wl-clipboard
    wl-clip-persist
    foot
    power-profiles-daemon
    gnome-power-manager
    libnotify
    nautilus
  ];
}
