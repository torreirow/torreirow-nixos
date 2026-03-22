{ config, pkgs, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    xwayland.enable = true;

    settings = {
      # Monitor configuration
      monitor = [
        "eDP-1,1920x1200@60,0x0,1"        # Laptop screen (left)
        "DVI-I-1,1920x1080@60,1920x0,1"   # External monitor (right)
        ",preferred,auto,1"                # Fallback for any other monitor
      ];

      # Environment variables
      env = [
        "QT_QPA_PLATFORM,wayland"
        "QT_QPA_PLATFORMTHEME,qt5ct"
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_TYPE,wayland"
        "XDG_SESSION_DESKTOP,Hyprland"
      ];

      # Startup applications (temporarily minimal for debugging)
      exec-once = [
        # "waybar"
        # "dunst"
        # "swayidle -w timeout 300 'swaylock -f' timeout 600 'hyprctl dispatch dpms off' resume 'hyprctl dispatch dpms on'"
        # "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
        # "gnome-keyring-daemon --start --components=secrets"
        # "wl-clip-persist --clipboard both"
        "alacritty"  # Start terminal so you can see what's happening
      ];

      # Input configuration
      input = {
        kb_layout = "us";
        kb_variant = "intl";
        follow_mouse = 1;

        touchpad = {
          natural_scroll = true;
          disable_while_typing = true;
        };

        sensitivity = 0;
      };

      # General window settings
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "rgba(89b4faee) rgba(94e2d5ee) 45deg";
        "col.inactive_border" = "rgba(313244aa)";

        layout = "dwindle";
        allow_tearing = false;
      };

      # Decoration (rounded corners, blur, shadows)
      decoration = {
        rounding = 8;

        blur = {
          enabled = true;
          size = 5;
          passes = 2;
          new_optimizations = true;
          xray = false;
          ignore_opacity = false;
        };

        drop_shadow = true;
        shadow_range = 20;
        shadow_render_power = 3;
        "col.shadow" = "rgba(1a1a1aee)";
      };

      # Animations
      animations = {
        enabled = true;

        bezier = [
          "wind, 0.05, 0.9, 0.1, 1.05"
          "winIn, 0.1, 1.1, 0.1, 1.1"
          "winOut, 0.3, -0.3, 0, 1"
          "liner, 1, 1, 1, 1"
        ];

        animation = [
          "windows, 1, 6, wind, slide"
          "windowsIn, 1, 6, winIn, slide"
          "windowsOut, 1, 5, winOut, slide"
          "windowsMove, 1, 5, wind, slide"
          "border, 1, 1, liner"
          "borderangle, 1, 30, liner, loop"
          "fade, 1, 10, default"
          "workspaces, 1, 5, wind"
        ];
      };

      # Layout settings
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      master = {
        new_status = "master";
      };

      # Gestures
      gestures = {
        workspace_swipe = true;
        workspace_swipe_fingers = 3;
      };

      # Misc settings
      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        mouse_move_enables_dpms = true;
        key_press_enables_dpms = true;
        force_default_wallpaper = 0;
      };

      # Keybindings
      "$mod" = "SUPER";

      bind = [
        # Application launchers
        "$mod, RETURN, exec, alacritty"
        "$mod, D, exec, rofi -show drun"
        "$mod, E, exec, nautilus"
        "$mod, B, exec, firefox"

        # Window management
        "$mod, Q, killactive"
        "$mod, F, fullscreen, 0"
        "$mod, V, togglefloating"
        "$mod, P, pseudo"
        "$mod, J, togglesplit"

        # Focus movement
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"

        # Workspace switching
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"

        # Move window to workspace
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"

        # Special workspace (scratchpad)
        "$mod, S, togglespecialworkspace, magic"
        "$mod SHIFT, S, movetoworkspace, special:magic"

        # Scroll through workspaces
        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"

        # Screenshots
        ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"
        "SHIFT, Print, exec, grim ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"

        # Lock screen
        "$mod, L, exec, swaylock"

        # System controls
        "$mod SHIFT, E, exit"
      ];

      # Mouse bindings
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      # Media keys
      bindl = [
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
      ];

      bindle = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];

      # Window rules
      windowrule = [
        "float, ^(pavucontrol)$"
        "float, ^(nm-connection-editor)$"
        "float, ^(blueman-manager)$"
        "float, ^(org.gnome.Calculator)$"
      ];

      windowrulev2 = [
        "opacity 0.90 0.90, class:^(alacritty)$"
        "opacity 0.95 0.95, class:^(firefox)$"
      ];
    };
  };
}
