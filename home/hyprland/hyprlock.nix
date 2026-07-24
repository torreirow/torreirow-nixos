{ ... }:

{
  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        disable_loading_bar = true;
        no_fade_in = false;
        hide_cursor = true;
        ignore_empty_input = true;
      };

      background = [{
        monitor = "";
        path = "screenshot";
        blur_passes = 1;
        blur_size = 8;
      }];

      input-field = [{
        monitor = "";
        size = "600, 80";
        position = "0, 0";
        halign = "center";
        valign = "center";

        inner_color = "rgb(504945)";    # Gruvbox bg2
        outer_color = "rgb(d5c4a1)";    # Gruvbox fg1
        outline_thickness = 4;

        font_family = "JetBrains Mono";
        font_size = 24;
        font_color = "rgb(d5c4a1)";     # Gruvbox fg1

        placeholder_color = "rgb(bdae93)"; # Gruvbox fg4
        placeholder_text = "The Secret...";
        check_color = "rgb(b8bb26)";    # Gruvbox green
        fail_text = "Fout wachtwoord";

        rounding = 4;
        shadow_passes = 0;
        fade_on_empty = false;
        dots_center = true;
      }];

      label = [{
        monitor = "";
        text = ''cmd[update:1000] echo "$(date +"%H:%M")"'';
        color = "rgb(d5c4a1)";          # Gruvbox fg1
        font_size = 64;
        font_family = "JetBrains Mono";
        position = "0, 120";
        halign = "center";
        valign = "center";
      }];
    };
  };
}
