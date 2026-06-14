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
      height = 32;
      spacing = 4;

      modules-left = [ "hyprland/workspaces" ];
      modules-center = [ "hyprland/window" ];
      modules-right = [ "pulseaudio" "battery" "clock" "tray" ];

      "hyprland/workspaces" = {
        format = "{id}";
        on-click = "activate";
      };

      "hyprland/window" = {
        max-length = 80;
      };

      "pulseaudio" = {
        format = " {volume}%";
        format-muted = " muted";
        on-click = "pactl set-sink-mute @DEFAULT_SINK@ toggle";
      };

      "battery" = {
        format = "{icon} {capacity}%";
        format-icons = ["" "" "" "" ""];
        states = {
          warning = 30;
          critical = 15;
        };
      };

      "clock" = {
        format = " {:%H:%M}";
        format-alt = " {:%d-%m-%Y}";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      };

      "tray" = {
        spacing = 10;
      };
    }];

    # Catppuccin Mocha kleuren
    style = ''
      * {
        font-family: "JetBrains Mono", monospace;
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background-color: rgba(30, 30, 46, 0.95);  /* Mocha base */
        color: #cdd6f4;                              /* Mocha text */
        border-bottom: 2px solid #cba6f7;           /* Mocha mauve */
      }

      #workspaces button {
        padding: 0 8px;
        color: #6c7086;                /* Mocha overlay0 */
        background: transparent;
        border-radius: 4px;
        margin: 4px 2px;
      }

      #workspaces button.active {
        color: #cba6f7;                /* Mocha mauve */
        background-color: rgba(203, 166, 247, 0.15);
      }

      #workspaces button:hover {
        background-color: rgba(203, 166, 247, 0.1);
        color: #cdd6f4;
      }

      #window {
        color: #cdd6f4;
        padding: 0 8px;
      }

      #clock,
      #battery,
      #pulseaudio,
      #tray {
        padding: 0 10px;
        color: #cdd6f4;
      }

      #battery.warning {
        color: #fab387;                /* Mocha peach */
      }

      #battery.critical {
        color: #f38ba8;                /* Mocha red */
      }
    '';
  };
}
