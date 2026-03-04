{ config, lib, pkgs, ... }:

{
  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        disable_loading_bar = false;
        grace = 0;
        hide_cursor = true;
        no_fade_in = false;
      };

      background = [
        {
          path = "screenshot";
          blur_passes = 3;
          blur_size = 7;
          noise = 0.0117;
          contrast = 0.8916;
          brightness = 0.8172;
          vibrancy = 0.1696;
          vibrancy_darkness = 0.0;
        }
      ];

      input-field = [
        {
          size = "300, 50";
          position = "0, -20";
          monitor = "";
          dots_center = true;
          fade_on_empty = false;
          font_color = "rgb(202, 211, 245)";
          inner_color = "rgb(30, 30, 46)";
          outer_color = "rgb(137, 180, 250)";
          outline_thickness = 2;
          placeholder_text = "<i>Password...</i>";
          shadow_passes = 2;
        }
      ];

      label = [
        # Clock
        {
          monitor = "";
          text = "cmd[update:1000] echo \"<b>$(date +'%H:%M')</b>\"";
          color = "rgb(202, 211, 245)";
          font_size = 90;
          font_family = "DejaVu Sans";
          position = "0, 300";
          halign = "center";
          valign = "center";
        }
        # Date
        {
          monitor = "";
          text = "cmd[update:1000] echo \"<b>$(date +'%A, %B %d')</b>\"";
          color = "rgb(202, 211, 245)";
          font_size = 20;
          font_family = "DejaVu Sans";
          position = "0, 200";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}
