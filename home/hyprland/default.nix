{ pkgs, lib, ... }:

let
  foggyForest = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/Vexhollow/Dotfiles/main/wallpapers/Foggy_forest.jpg";
    hash = "sha256-noQeH3DsWF/KTMjrk/zAGyFYVGxa1sTmiCk4GC1mDyU=";
  };
in

{
  imports = [
    ./waybar.nix
    ./hyprlock.nix
    ./hypridle.nix
    ./mako.nix
    ./rofi.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang";

    settings = {
      "$mod" = "SUPER";

      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "rgba(cba6f7ff)";   # Catppuccin Mocha mauve
        "col.inactive_border" = "rgba(585b70ff)"; # Catppuccin Mocha surface2
      };

      decoration = {
        rounding = 8;
        blur = {
          enabled = true;
          size = 5;
          passes = 2;
        };
      };

      animations = {
        enabled = true;
      };

      input = {
        kb_layout = "us";
        kb_variant = "intl";
        follow_mouse = 1;
        touchpad = {
          natural_scroll = true;
        };
      };

      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
      };

      exec-once = [
        "uwsm finalize HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "hyprpaper"
        "hypridle"
      ];

      bind = [
        "$mod, Return, exec, uwsm app -- kitty"
        "$mod, D, exec, uwsm app -- rofi -show drun -show-icons"
        "$mod, Q, killactive"
        "$mod, L, exec, hyprlock"
        "$mod, F, fullscreen"
        "$mod, H, movefocus, l"
        "$mod, J, movefocus, d"
        "$mod, K, movefocus, u"
        "$mod, semicolon, movefocus, r"
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        ", Print, exec, grimblast copy area"
        "SHIFT, Print, exec, grimblast save area"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };

  gtk = {
    enable = true;
    gtk4.theme = {
      package = pkgs.catppuccin-gtk.override {
        accents = [ "mauve" ];
        variant = "mocha";
      };
      name = "catppuccin-mocha-mauve-standard+default";
    };
    theme = {
      package = pkgs.catppuccin-gtk.override {
        accents = [ "mauve" ];
        variant = "mocha";
      };
      name = "catppuccin-mocha-mauve-standard+default";
    };
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
    cursorTheme = {
      package = pkgs.catppuccin-cursors.mochaDark;
      name = "catppuccin-mocha-dark-cursors";
      size = 24;
    };
  };

  home.pointerCursor = {
    package = pkgs.catppuccin-cursors.mochaDark;
    name = "catppuccin-mocha-dark-cursors";
    size = 24;
    gtk.enable = true;
  };

  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "off";
      splash = false;
      preload = [ "${foggyForest}" ];
      wallpaper = [
        "eDP-1,${foggyForest}"
        "DP-10,${foggyForest}"
      ];
    };
  };
}
