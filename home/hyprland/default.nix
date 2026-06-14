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
    ./walker.nix
    ./looknfeel.nix
    ./bindings.nix
    ./windows.nix
    ./input.nix
    ./envs.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang";

    settings = {
      "$terminal" = "uwsm app -- kitty";
      "$browser" = "uwsm app -- firefox";

      monitor = [
        "eDP-1,preferred,auto,1"
        "DP-10,preferred,auto,1"
      ];

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        disable_watchdog_warning = true;
      };

      exec-once = [
        "uwsm finalize HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "hyprsunset"
        "wl-clip-persist --clipboard regular"
        "elephant"
        "walker --gapplication-service"
      ];
    };
  };

  gtk = {
    enable = true;
    gtk4.theme = null;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
    cursorTheme = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
      size = 24;
    };
  };

  home.pointerCursor = {
    package = pkgs.adwaita-icon-theme;
    name = "Adwaita";
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
