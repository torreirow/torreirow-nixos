{ pkgs, solidtime-waybar-input, ... }:

let
  solidtime-waybar-pkg = solidtime-waybar-input.packages.${pkgs.system}.default;

  planify-badge = pkgs.writeShellScript "planify-badge" ''
    db="$HOME/.local/share/io.github.alainm23.planify/database.db"
    count=$(${pkgs.sqlite}/bin/sqlite3 "$db" \
      "SELECT COUNT(*) FROM Items JOIN Projects ON Items.project_id = Projects.id \
       WHERE Items.checked=0 AND Items.is_deleted=0 \
       AND Projects.name='TN-ToDO' AND Projects.is_deleted=0;" 2>/dev/null)
    printf '{"text":"%s"}' "''${count:-0}"
  '';

  solidtime-timer = pkgs.writeShellScript "solidtime-timer" ''
    output=$(SOLIDTIME_BASE_URL="https://solidtime.tools.technative.cloud" \
      SOLIDTIME_CACHE_TTL="10" \
      ${solidtime-waybar-pkg}/bin/solidtime-waybar)
    printf '%s' "$output" | ${pkgs.jq}/bin/jq -c 'if .text == "" then .text = "⏱ stopped" else . end'
  '';

  monitor-router = pkgs.writeShellScript "wayle-monitor-router" ''
    set_monitor() {
      local monitor
      monitor=$(${pkgs.hyprland}/bin/hyprctl monitors -j 2>/dev/null \
        | ${pkgs.jq}/bin/jq -r '[.[] | select(.name != "eDP-1")] | first | .name // "primary"')
      ${pkgs.wayle}/bin/wayle config set modules.notifications.popup-monitor "$monitor"
      ${pkgs.wayle}/bin/wayle config set osd.monitor "$monitor"
    }

    set_monitor

    SOCKET="/run/user/$UID/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
    ${pkgs.socat}/bin/socat -u "UNIX-CONNECT:$SOCKET" - | while IFS= read -r event; do
      case "$event" in
        monitoraddedv2*|monitorremoved*)
          set_monitor
          ;;
      esac
    done
  '';

  workspace-binder = pkgs.writeShellScript "hyprland-workspace-binder" ''
    bind_workspaces() {
      local extern
      extern=$(${pkgs.hyprland}/bin/hyprctl monitors -j 2>/dev/null \
        | ${pkgs.jq}/bin/jq -r '[.[] | select(.name != "eDP-1")] | first | .name // empty')

      if [ -n "$extern" ]; then
        for ws in 1 4 6 8 10; do
          ${pkgs.hyprland}/bin/hyprctl dispatch wsbind "$ws" "$extern" >/dev/null
          ${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor "$ws" "$extern" >/dev/null
        done
        for ws in 3 5 7 9; do
          ${pkgs.hyprland}/bin/hyprctl dispatch wsbind "$ws" "eDP-1" >/dev/null
          ${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor "$ws" "eDP-1" >/dev/null
        done
      fi
    }

    bind_workspaces

    SOCKET="/run/user/$UID/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
    ${pkgs.socat}/bin/socat -u "UNIX-CONNECT:$SOCKET" - | while IFS= read -r event; do
      case "$event" in
        monitoraddedv2*|monitorremoved*)
          sleep 1
          bind_workspaces
          ;;
      esac
    done
  '';
in

{
  home.packages = [ pkgs.wayle ];

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

  systemd.user.services.wayle-monitor-router = {
    Unit = {
      Description = "Route wayle notificatie-popups naar actief extern scherm";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" "wayle.service" ];
    };
    Service = {
      ExecStart = "${monitor-router}";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.hyprland-workspace-binder = {
    Unit = {
      Description = "Bind Hyprland workspaces dynamisch aan extern scherm";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${workspace-binder}";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  xdg.configFile."wayle/config.toml".text = ''
    [bar]
    location = "top"
    scale = 0.8
    bg = "transparent"

    [styling.palette]
    bg = "#16161e"
    surface = "#1a1b26"
    elevated = "#292e42"
    fg = "#c0caf5"
    fg-muted = "#a9b1d6"
    primary = "#7aa2f7"
    red = "#f7768e"
    yellow = "#e0af68"
    green = "#9ece6a"
    blue = "#7dcfff"

    [[bar.layout]]
    monitor = "*"
    left = ["dashboard", "hyprland-workspaces", "window-title"]
    center = ["custom-solidtime", "clock", "weather"]
    right = ["custom-clipboard", "custom-planify", "media", "volume", "battery", "notifications", "systray"]

    [modules.dashboard]
    dropdown-lock-command = "loginctl lock-session"
    dropdown-reboot-command = "systemctl reboot"
    dropdown-poweroff-command = "systemctl poweroff"

    [modules.clock]
    format = " %Y-%m-%d  %H:%M"

    [modules.weather]
    units = "metric"

    [[modules.weather.locations]]
    location = "52.2983,5.6222"
    name = "Ermelo"

    [[modules.weather.locations]]
    location = "52.1561,5.3878"
    name = "Amersfoort"

    [[modules.weather.locations]]
    location = "-14.4833,31.3167"
    name = "Petauke"

    [modules.media]
    icon-type = "default"
    label-max-length = 30

    [modules.volume]
    label-show = true

    [modules.battery]
    label-show = true

    [modules.notifications]
    popup-position = "top-right"

    [modules.hyprland-workspaces]
    monitor-specific = true
    show-special = false

    [modules.systray]
    icon-scale = 1.0

    [osd]
    monitor = "focussed"

    [modules.planify]
    project = "TN-ToDO"

    [[modules.custom]]
    id = "clipboard"
    interval-ms = 0
    mode = "poll"
    format = ""
    label-show = false
    icon-show = true
    icon-name = "edit-copy-symbolic"
    left-click = "dropdown:clipboard"

    [[modules.custom]]
    id = "planify"
    interval-ms = 60000
    mode = "poll"
    command = "${planify-badge}"
    format = "{{ text }}"
    label-show = true
    icon-show = true
    icon-name = "checkbox-checked-symbolic"
    left-click = "dropdown:planify"
    right-click = "uwsm app -- io.github.alainm23.planify"

    [[modules.custom]]
    id = "solidtime"
    command = "${solidtime-timer}"
    interval-ms = 10000
    mode = "poll"
    format = "{{ text }}"
    tooltip-format = "{{ tooltip }}"
    label-show = true
    icon-show = false
    left-click = "solidtime-desktop"
  '';
}
