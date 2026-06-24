{ pkgs, solidtime-waybar-input, ... }:

let
  solidtime-waybar-pkg = solidtime-waybar-input.packages.${pkgs.system}.default;

  solidtime-timer = pkgs.writeShellScript "solidtime-timer" ''
    SOLIDTIME_BASE_URL="https://solidtime.tools.technative.cloud" \
    SOLIDTIME_CACHE_TTL="10" \
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
in

{
  home.packages = [ pkgs.wayle ];

  systemd.user.services.spotify-tray-wayland = {
    Unit = {
      Description = "Spotify system tray for Wayland";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.spotify-tray-wayland}/bin/spotify-tray-wayland";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.wayle = {
    Unit = {
      Description = "Wayle shell";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wayle}/bin/wayle shell";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  xdg.configFile."wayle/styles/index.scss".text = ''
    window.bar menubutton.bar-button label {
      font-size: 12px;
    }
  '';

  xdg.configFile."wayle/config.toml".text = ''
    [styling]
    rounding = "sm"

    [bar]
    location = "top"
    inset-edge = 0.35
    inset-ends = 0.5
    module-gap = 0.5
    padding = 0.35
    rounding = "sm"

    [[bar.layout]]
    monitor = "*"
    left = ["dashboard", "hyprland-workspaces", "window-title"]
    center = ["clock"]
    right = ["custom-solidtime", "media", "custom-powerprofile", "volume", "battery", "notifications", "custom-clipse", "systray"]

    [modules.dashboard]
    dropdown-lock-command = "loginctl lock-session"
    dropdown-reboot-command = "systemctl reboot"
    dropdown-poweroff-command = "systemctl poweroff"

    [modules.weather]
    location = "52.2983,5.6222"
    units = "metric"
    time-format = "24h"

    [modules.window-title]
    label-show = false

    [modules.clock]
    format = " %Y-%m-%d  %H:%M"

    [modules.media]
    format = "{{ title }} - {{ artist }}"
    label-max-length = 50
    icon-show = true
    label-show = true
    player-priority = ["*strawberry*", "*spotify*"]
    players-ignored = ["*playerctld*"]

    [modules.volume]
    label-show = true

    [modules.battery]
    format = "{{ percent }}%"
    label-show = true

    [modules.notifications]
    popup-monitor = "primary"
    popup-duration = 5000
    popup-position = "top-right"

    [modules.systray]
    icon-scale = 1.0

    [modules.hyprland-workspaces]
    monitor-specific = true
    numbering = "absolute"
    show-special = false

    [[modules.custom]]
    id = "solidtime"
    command = "${solidtime-timer}"
    interval-ms = 1000
    mode = "poll"
    format = "{{ text }}"
    tooltip-format = "{{ tooltip }}"
    label-show = true
    icon-show = false
    left-click = "solidtime-desktop"

    [[modules.custom]]
    id = "powerprofile"
    command = "${power-profile-icon}"
    interval-ms = 5000
    mode = "poll"
    label-show = true
    icon-show = false
    left-click = "${power-profile-menu}"
    right-click = "${power-menu}"

    [[modules.custom]]
    id = "clipse"
    command = "printf '󰅌'"
    interval-ms = 0
    label-show = true
    icon-show = false
    left-click = "kitty --title=clipse clipse"
  '';
}
