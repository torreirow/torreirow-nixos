{ pkgs, lib, ... }:

let
  # Apps die stil (zonder focuswissel) op een vaste workspace openen. `class` is een ERE die
  # hoofdletterongevoelig matcht; `name` is wat de melding toont. Hieruit komen zowel de
  # windowrules als de notifier.
  silentApps = [
    { workspace = 2; class = "slack"; name = "Slack"; }
    { workspace = 3; class = "teams-for-linux"; name = "Teams"; }
    { workspace = 4; class = "firefox"; name = "Firefox"; }
    { workspace = 10; class = "signal"; name = "Signal"; }
    { workspace = 10; class = "com\\.rtosta\\.zapzap|zapzap"; name = "ZapZap"; }
  ];

  # Hyprland heeft geen exec-windowrule, dus luisteren we op de event-socket naar openwindow.
  # Melding alleen bij het eerste venster van die class, zodat popups/extra vensters niet spammen.
  silent-start-notifier = pkgs.writeShellScript "hyprland-silent-start-notifier" ''
    notify() {
      local ws="$1" class="$2" name="$3" count
      count=$(${pkgs.hyprland}/bin/hyprctl clients -j 2>/dev/null \
        | ${pkgs.jq}/bin/jq --arg c "$class" '[.[] | select(.class == $c)] | length')
      [ "''${count:-0}" -le 1 ] || return 0
      ${pkgs.libnotify}/bin/notify-send -a Hyprland -i window-new \
        "$name started" "Opened on workspace $ws" 2>/dev/null || true
    }

    SOCKET="/run/user/$UID/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
    ${pkgs.socat}/bin/socat -u "UNIX-CONNECT:$SOCKET" - | while IFS= read -r event; do
      case "$event" in
        openwindow\>\>*)
          IFS=, read -r _ ws class _ <<< "''${event#openwindow>>}"
    ${lib.concatMapStrings (a: ''
          [ "$ws" = ${toString a.workspace} ] && echo "$class" | ${pkgs.gnugrep}/bin/grep -Eiqx '${a.class}' && notify "$ws" "$class" '${a.name}'
    '') silentApps}
          ;;
      esac
    done
  '';
in

{
  systemd.user.services.hyprland-silent-start-notifier = {
    Unit = {
      Description = "Melding als een app stil op een andere workspace opent";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${silent-start-notifier}";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  wayland.windowManager.hyprland.settings = {
    windowrule = [
      "suppress_event maximize, match:class .*"

      "tile on, match:class ^(chromium)$"

      "float on, match:class ^(org.pulseaudio.pavucontrol|blueman|nwg-displays)$"
      "float on, match:class ^(steam)$"
      "float on, match:class ^(vlc)$, match:title ^(Open Media)$"

      "opacity 1.0 1.0, match:class .*"
      "opacity 1 1, match:class ^(chromium|google-chrome)$, match:title .*Youtube.*"
      "opacity 1 0.97, match:class ^(chromium|google-chrome)$"
      "opacity 1 1, match:class ^(zoom|vlc|com.obsproject.Studio)$"
      "opacity 1 1, match:class ^(steam)$"

      "no_focus on, match:class ^$, match:title ^$, match:xwayland 1, match:float 1, match:fullscreen 0, match:pin 0"
    ]
    ++ map (a: "workspace ${toString a.workspace} silent, match:class (?i)^(${a.class})$") silentApps
    ++ [
      "float on, match:title (nmtui)"
      "size 622 652, match:title (nmtui)"
      "stay_focused on, match:title (nmtui)"
    ];

    layerrule = [
      "blur on, match:namespace walker"
    ];
  };
}
