{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    windowrule = [
      "suppress_event maximize, match:class .*"

      "tile on, match:class ^(chromium)$"

      "float on, match:class ^(org.pulseaudio.pavucontrol|blueman|nwg-displays)$"
      "float on, match:class ^(steam)$"

      "opacity 1.0 1.0, match:class .*"
      "opacity 1 1, match:class ^(chromium|google-chrome)$, match:title .*Youtube.*"
      "opacity 1 0.97, match:class ^(chromium|google-chrome)$"
      "opacity 1 1, match:class ^(zoom|vlc|com.obsproject.Studio)$"
      "opacity 1 1, match:class ^(steam)$"

      "no_focus on, match:class ^$, match:title ^$, match:xwayland 1, match:float 1, match:fullscreen 0, match:pin 0"

      "workspace 3 silent, match:class ^(Slack)$"
      "workspace 3 silent, match:class ^(teams-for-linux)$"
      "workspace 4 silent, match:class ^(firefox)$"

      "float on, match:title (clipse)"
      "size 622 652, match:title (clipse)"
      "stay_focused on, match:title (clipse)"

      "float on, match:title (nmtui)"
      "size 622 652, match:title (nmtui)"
      "stay_focused on, match:title (nmtui)"
    ];

    layerrule = [
      "blur on, match:namespace walker"
    ];
  };
}
