{ config, pkgs, ... }:

{
  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;

    settings = {
      # Display
      screenshots = true;
      effect-blur = "7x5";
      effect-vignette = "0.5:0.5";
      clock = true;
      indicator = true;
      indicator-radius = 100;
      indicator-thickness = 7;

      # Colors (Catppuccin-inspired)
      color = "1e1e2e";
      bs-hl-color = "f38ba8";
      key-hl-color = "a6e3a1";
      separator-color = "00000000";

      inside-color = "1e1e2e";
      inside-clear-color = "f9e2af";
      inside-caps-lock-color = "f9e2af";
      inside-ver-color = "89b4fa";
      inside-wrong-color = "f38ba8";

      ring-color = "313244";
      ring-clear-color = "f9e2af";
      ring-caps-lock-color = "f9e2af";
      ring-ver-color = "89b4fa";
      ring-wrong-color = "f38ba8";

      line-color = "00000000";
      line-clear-color = "00000000";
      line-caps-lock-color = "00000000";
      line-ver-color = "00000000";
      line-wrong-color = "00000000";

      text-color = "cdd6f4";
      text-clear-color = "1e1e2e";
      text-ver-color = "1e1e2e";
      text-wrong-color = "1e1e2e";

      # Grace period
      grace = 2;
      grace-no-mouse = true;
      grace-no-touch = true;

      # Behavior
      daemonize = true;
      show-failed-attempts = true;
      ignore-empty-password = true;
    };
  };

  # Swayidle for auto-locking
  services.swayidle = {
    enable = true;
    events = [
      { event = "before-sleep"; command = "${pkgs.swaylock-effects}/bin/swaylock -f"; }
      { event = "lock"; command = "${pkgs.swaylock-effects}/bin/swaylock -f"; }
    ];
    timeouts = [
      { timeout = 300; command = "${pkgs.swaylock-effects}/bin/swaylock -f"; }
      {
        timeout = 600;
        command = "${pkgs.hyprland}/bin/hyprctl dispatch dpms off";
        resumeCommand = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";
      }
    ];
  };
}
