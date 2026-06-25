{ pkgs, ... }:

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

  xdg.configFile."wayle/config.toml".text = ''
    [bar]
    location = "top"

    [[bar.layout]]
    monitor = "*"
    left = ["dashboard", "hyprland-workspaces", "window-title"]
    center = ["clock"]
    right = ["media", "volume", "battery", "notifications", "systray"]

    [modules.dashboard]
    dropdown-lock-command = "loginctl lock-session"
    dropdown-reboot-command = "systemctl reboot"
    dropdown-poweroff-command = "systemctl poweroff"

    [modules.clock]
    format = " %Y-%m-%d  %H:%M"

    [modules.media]
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
  '';
}
