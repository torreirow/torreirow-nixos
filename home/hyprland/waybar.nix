{ pkgs, ... }:

{
  systemd.user.services.waybar = {
    Unit = {
      Description = "Waybar";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.waybar}/bin/waybar";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  programs.waybar = {
    enable = true;

    settings = [{
      layer = "top";
      position = "top";
      height = 34;
      spacing = 4;

      modules-left = [ "hyprland/workspaces" "hyprland/window" "mpris" ];
      modules-center = [ "clock" ];
      modules-right = [ "pulseaudio" "battery" "tray" ];


      "hyprland/workspaces" = {
        format = "{id}";
        on-click = "activate";
        active-only = false;
      };

      "hyprland/window" = {
        max-length = 60;
        separate-outputs = true;
      };

      "mpris" = {
        format = "{player_icon} {dynamic}";
        format-paused = "{status_icon} {dynamic}";
        player-icons = {
          default = "▶";
          strawberry = "🍓";
          spotify = "";
        };
        status-icons = {
          paused = "⏸";
        };
        dynamic-len = 50;
        dynamic-importance-order = [ "title" "artist" "position" "length" ];
      };

      "pulseaudio" = {
        format = "{icon} {volume}%";
        format-muted = "󰝟 muted";
        format-icons = {
          default = [ "󰕿" "󰖀" "󰕾" ];
          headphone = "󰋋";
          headset = "󰋎";
          phone = "󰏲";
          portable = "󰏲";
          car = "󰄋";
          bluetooth = "󰂰";
        };
        on-click = "pavucontrol";
        on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        scroll-step = 5;
      };

      "battery" = {
        format = "{icon} {capacity}%";
        format-icons = [ "" "" "" "" "" ];
        states = {
          warning = 30;
          critical = 15;
        };
      };

      "clock" = {
        format = " {:%Y-%m-%d  %H:%M}";
        format-alt = " {:%d-%m-%Y}";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      };

      "tray" = {
        spacing = 10;
      };
    }];

    style = ''
      * {
        font-family: "JetBrains Mono", monospace;
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background-color: rgba(29, 32, 33, 0.95);
        color: #d5c4a1;
        border-bottom: 2px solid #83a598;
      }

      #workspaces button {
        padding: 0 8px;
        color: #665c54;
        background: transparent;
        border-radius: 4px;
        margin: 4px 2px;
      }

      #workspaces button.active {
        color: #83a598;
        background-color: rgba(131, 165, 152, 0.15);
      }

      #workspaces button:hover {
        background-color: rgba(131, 165, 152, 0.1);
        color: #d5c4a1;
      }

      #window {
        color: #bdae93;
        padding: 0 8px;
      }

      #clock {
        color: #fabd2f;
        padding: 0 12px;
        font-weight: bold;
      }

      #battery,
      #pulseaudio,
      #tray {
        padding: 0 10px;
        color: #d5c4a1;
      }

      #battery.warning {
        color: #fe8019;
      }

      #battery.critical {
        color: #fb4934;
      }

      #mpris {
        color: #8ec07c;
        padding: 0 10px;
      }
    '';
  };
}
