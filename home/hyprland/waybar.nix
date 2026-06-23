{ pkgs, solidtime-waybar-input, ... }:

let
  solidtime-waybar-pkg = solidtime-waybar-input.packages.${pkgs.system}.default;

  solidtime-timer = pkgs.writeShellScript "solidtime-timer" ''
    SOLIDTIME_BASE_URL="https://solidtime.tools.technative.cloud" \
      ${solidtime-waybar-pkg}/bin/solidtime-waybar
  '';

  power-profile-icon = pkgs.writeShellScript "power-profile-icon" ''
    case $(powerprofilesctl get) in
      performance) echo "⚡";;
      balanced)    echo "⚖";;
      power-saver) echo "🍃";;
      *)           echo "?";;
    esac
  '';

  power-profile-menu = pkgs.writeShellScript "power-profile-menu" ''
    current=$(powerprofilesctl get)
    chosen=$(printf "performance\nbalanced\npower-saver" | \
      ${pkgs.rofi}/bin/rofi -dmenu -i -p "Power profile (huidig: $current)" \
        -theme-str 'window {width: 260px;}')
    [ -z "$chosen" ] && exit 0
    powerprofilesctl set "$chosen"
    notify-send "Power profile" "Ingesteld op: $chosen" -t 2000
  '';

  power-menu = pkgs.writeShellScript "power-menu" ''
    threshold=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null || echo 100)
    if [ "$threshold" -ge 100 ]; then
      limit_label="🔋 Laadlimiet: 100%  →  80% instellen"
    else
      limit_label="🔋 Laadlimiet: 80%  →  100% instellen"
    fi

    chosen=$(printf "🔒 Vergrendelen\n💤 Slaapstand\n❄️  Hibernatie\n🔄 Herstarten\n⏻  Uitzetten\n$limit_label" | \
      ${pkgs.rofi}/bin/rofi -dmenu -p "Stroom" -theme-str 'window {width: 320px;}')
    [ -z "$chosen" ] && exit 0

    case "$chosen" in
      *Vergrendelen*) loginctl lock-session;;
      *Slaapstand*)   systemctl suspend;;
      *Hibernatie*)   systemctl hibernate;;
      *Herstarten*)   systemctl reboot;;
      *Uitzetten*)    systemctl poweroff;;
      *Laadlimiet*)
        if [ "$threshold" -ge 100 ]; then new=80; else new=100; fi
        echo "$new" | sudo tee /sys/class/power_supply/BAT0/charge_control_end_threshold > /dev/null
        echo "$new" > /var/lib/battery-threshold
        notify-send "Batterij" "Laadlimiet ingesteld op ''${new}%" -t 2000
        ;;
    esac
  '';

  audio-switcher = pkgs.writeShellScriptBin "audio-switcher" ''
    sinks=$(wpctl status | awk '
      /Sinks:/{p=1; next}
      /Sources:/{p=0}
      p && /[0-9]+\./{
        match($0, /[0-9]+\./)
        id = substr($0, RSTART, RLENGTH-1)
        rest = substr($0, RSTART+RLENGTH)
        gsub(/^ +/, "", rest)
        gsub(/ +\[vol:.*$/, "", rest)
        print id "|" rest
      }
    ')

    if [ -z "$sinks" ]; then
      notify-send "Audio" "Geen audio outputs gevonden" -t 2000
      exit 1
    fi

    chosen=$(echo "$sinks" | awk -F'|' '{print $2}' | \
      ${pkgs.rofi}/bin/rofi -dmenu -p "Audio Output" -i)
    [ -z "$chosen" ] && exit 0

    sink_id=$(echo "$sinks" | awk -F'|' -v d="$chosen" '$2 == d {print $1; exit}')
    wpctl set-default "$sink_id"
    notify-send "Audio" "Output: $chosen" -t 2000
  '';
in

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
      modules-right = [ "custom/solidtime" "pulseaudio" "custom/powerprofile" "battery" "custom/clipse" "custom/swaync" "tray" ];


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
        on-click = "${audio-switcher}/bin/audio-switcher";
        on-click-right = "pavucontrol";
        on-click-middle = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        scroll-step = 5;
      };

      "custom/powerprofile" = {
        exec = "${power-profile-icon}";
        interval = 5;
        on-click = "${power-profile-menu}";
        on-click-right = "${power-menu}";
        tooltip = false;
      };

      "battery" = {
        format = "{icon} {capacity}%";
        format-charging = "󰂄 {capacity}%";
        format-plugged = "󰁹 {capacity}%";
        format-icons = [ "" "" "" "" "" ];
        states = {
          warning = 30;
          critical = 15;
        };
        on-click = "${power-profile-menu}";
        on-click-right = "${power-menu}";
        tooltip-format = "{timeTo}";
      };

      "clock" = {
        format = " {:%Y-%m-%d  %H:%M}";
        format-alt = " {:%d-%m-%Y}";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      };

      "custom/solidtime" = {
        exec = "${solidtime-timer}";
        interval = 1;
        return-type = "json";
        on-click = "solidtime-desktop";
        tooltip = true;
      };

      "custom/clipse" = {
        format = "󰅌";
        tooltip = false;
        on-click = "kitty --title=clipse clipse";
      };

      "custom/swaync" = {
        exec = "swaync-client -swb";
        return-type = "json";
        format = "󰇰 {}";
        on-click = "swaync-client -t -sw";
        on-click-right = "swaync-client -d -sw";
        escape = true;
        tooltip = false;
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

      #custom-powerprofile {
        padding: 0 0 0 10px;
        margin-right: -5px;
        color: #8ec07c;
      }

      #battery {
        padding: 0 10px 0 0;
      }

      #battery.warning {
        color: #fe8019;
      }

      #battery.critical {
        color: #fb4934;
      }

      #custom-clipse {
        padding: 0 10px;
        color: #d5c4a1;
      }

      #custom-swaync {
        padding: 0 10px;
        color: #d5c4a1;
      }

      #custom-swaync.none {
        color: #665c54;
      }

      #custom-swaync.notification {
        color: #fabd2f;
      }

      #custom-swaync.dnd-notification,
      #custom-swaync.dnd-none,
      #custom-swaync.dnd {
        color: #fb4934;
      }

      #mpris {
        color: #8ec07c;
        padding: 0 10px;
      }

      #custom-solidtime {
        padding: 0 10px;
        color: #665c54;
      }

      #custom-solidtime.active {
        color: #b8bb26;
      }
    '';
  };
}
