{ pkgs, lib, config, ... }:

let
  wallpaper = "${config.home.homeDirectory}/Pictures/_backgrounds/bg-christ-splash.jpg";
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
        "swww-daemon"
        "swww img ${wallpaper} --transition-type none"
        "hyprsunset"
        "wl-clip-persist --clipboard regular"
        "elephant"
        "sh -c 'until [ -S /run/user/1000/elephant/elephant.sock ]; do sleep 0.1; done; walker --gapplication-service'"
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

  home.packages = [ pkgs.swww ];
}
