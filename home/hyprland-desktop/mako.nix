{ config, lib, pkgs, ... }:

{
  services.mako = {
    enable = true;

    settings = {
      # Appearance
      background-color = "#1e1e2e";
      text-color = "#cdd6f4";
      border-color = "#89b4fa";
      border-radius = 8;
      border-size = 2;

      # Positioning
      width = 300;
      height = 100;
      margin = "10";
      padding = "10";

      # Behavior
      default-timeout = 5000;
      ignore-timeout = false;

      # Icons
      icons = true;
      max-icon-size = 48;

      # Font
      font = "DejaVu Sans 11";
    };

    # Extra configuration
    extraConfig = ''
      [urgency=low]
      border-color=#94e2d5

      [urgency=normal]
      border-color=#89b4fa

      [urgency=high]
      border-color=#f38ba8
      default-timeout=0
    '';
  };
}
