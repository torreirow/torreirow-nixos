{ ... }:

{
  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        hide_cursor = true;
        ignore_empty_input = true;
      };

      background = [{
        path = "screenshot";
        blur_passes = 3;
        blur_size = 8;
        color = "rgba(30, 30, 46, 1.0)"; # Mocha base
      }];

      label = [{
        monitor = "";
        text = ''cmd[update:1000] echo "$(date +"%H:%M")"'';
        color = "rgba(205, 214, 244, 1.0)"; # Mocha text
        font_size = 64;
        font_family = "JetBrains Mono";
        position = "0, 80";
        halign = "center";
        valign = "center";
      }];

      input-field = [{
        size = "250, 50";
        position = "0, -60";
        monitor = "";
        dots_center = true;
        fade_on_empty = false;
        font_color = "rgba(205, 214, 244, 1.0)"; # Mocha text
        inner_color = "rgba(49, 50, 68, 1.0)";   # Mocha surface0
        outer_color = "rgba(203, 166, 247, 1.0)"; # Mocha mauve
        outline_thickness = 3;
        placeholder_text = "Wachtwoord...";
        shadow_passes = 2;
      }];
    };
  };
}
