{ pkgs, lib, config, ... }:

let
  wallpaper = "${config.home.homeDirectory}/Pictures/_backgrounds/bg-christ-splash.jpg";
in

  {
    imports = [
      ./wayle.nix
      ./hyprlock.nix
      ./hypridle.nix

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
        "$terminal" = "uwsm app -- alacritty";
        "$browser" = "uwsm app -- firefox";

        monitor = [
          "eDP-1,preferred,auto,1.25"
          "HDMI-A-1,preferred,auto,1"
        ];

        workspace = [
          "1, default:true, persistent:true"
          "2, monitor:eDP-1, default:true, persistent:true"
          "3, monitor:eDP-1, persistent:true"
          "4, persistent:true"
          "5, monitor:eDP-1, persistent:true"
          "6, persistent:true"
          "7, monitor:eDP-1, persistent:true"
          "8, persistent:true"
          "9, persistent:true"
          "10, persistent:true"
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
          "autocutsel -fork"
          "autocutsel -selection PRIMARY -fork"
          "clipse -listen"
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

    services.hyprpaper = {
      enable = true;
      settings = {
        preload = [ wallpaper ];
      wallpaper = [
            {
              monitor = "";
              path = wallpaper;
              fit_mode = "cover";
            }
          ];
    };        
    
    };
}

