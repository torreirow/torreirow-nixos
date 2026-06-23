{ pkgs, hyprswitch-input, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  hyprswitch-pkg = hyprswitch-input.packages.${system}.default;

  smart-close = pkgs.writeShellScript "smart-close" ''
    class=$(hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r '.class // ""')
    case "$class" in
      Spotify|spotify)
        hyprctl dispatch movetoworkspacesilent special:spotify,class:$class
        ;;
      *)
        hyprctl dispatch killactive
        ;;
    esac
  '';

  shortcuts-popup = pkgs.writeShellScript "shortcuts-popup" ''
    shortcuts=$(cat <<'SHORTCUTS'
    ─── Applicaties ──────────────────────────────────────────
    SUPER + Enter              Terminal
    SUPER + E                  Bestandsbeheer (Nautilus)
    SUPER + B                  Browser
    SUPER + SPACE              App launcher (rofi)
    ─── Vensters ─────────────────────────────────────────────
    SUPER + Q / Backspace      Venster sluiten (Spotify: naar achtergrond)
    SUPER+SHIFT + Q            Spotify tonen/verbergen
    SUPER + V                  Zwevend venster aan/uit
    SUPER + F                  Volledig scherm
    SUPER + M                  Maximize
    SUPER + J                  Split richting wisselen
    SUPER + P                  Pseudo tiling
    ─── Focus ────────────────────────────────────────────────
    SUPER + ←/→/↑/↓            Focus verplaatsen
    SUPER+SHIFT + ←/→/↑/↓      Vensters wisselen
    ─── Workspaces ───────────────────────────────────────────
    SUPER + 1-0                Naar workspace 1-10
    SUPER + , / .              Vorige / volgende workspace
    SUPER+SHIFT + 1-0          Venster naar workspace
    SUPER + S                  Special workspace tonen
    SUPER+SHIFT + S            Venster naar special workspace
    ─── Monitor ──────────────────────────────────────────────
    SUPER+ALT + ←/→            Venster naar andere monitor
    ─── Venstergrootte ───────────────────────────────────────
    SUPER + - / =              100px smaller / breder
    SUPER+SHIFT + - / =        100px lager / hoger
    ─── Systeem ──────────────────────────────────────────────
    SUPER + L                  Scherm vergrendelen
    SUPER+SHIFT + L            Vergrendelen + slaapstand
    SUPER+SHIFT + Escape       Hyprland afsluiten
    ─── Screenshots ──────────────────────────────────────────
    SUPER+CTRL + S             Screenshot (regio selectie)
    SUPER+CTRL + W             Screenshot (actief venster)
    Print                      Screenshot (regio selectie)
    CTRL + Print               Screenshot (volledig scherm)
    SUPER + Print              Kleurpicker
    ─── Diversen ─────────────────────────────────────────────
    SUPER+SHIFT + K            Sneltoetsen (dit scherm)
    CTRL+SUPER + V             Klembord (clipse)
    CTRL+SUPER + N             Netwerk (nmtui)
    ALT + Tab                  Vensterlijst (rofi)
    SHORTCUTS
    )
    echo "$shortcuts" | rofi -dmenu -p "⌨  Sneltoetsen" \
      -theme-str 'window {width: 660px;} listview {lines: 32; scrollbar: false;}' \
      -no-custom
  '';
in

{
  wayland.windowManager.hyprland.settings = {
    bind = [
      "SUPER, Return, exec, $terminal"
      "SUPER, E, exec, uwsm app -- nautilus --new-window"
      "SUPER, B, exec, $browser"

      "SUPER, SPACE, exec, rofi -show drun -show-icons"
      "SUPER, Q, exec, ${smart-close}"
      "SUPER, Backspace, exec, ${smart-close}"
      "SUPER SHIFT, Q, togglespecialworkspace, spotify"

      "SUPER, L, exec, hyprlock"
      "SUPER SHIFT, L, exec, hyprlock & disown && systemctl suspend"
      "SUPER SHIFT, ESCAPE, exit,"

      "SUPER, J, layoutmsg, togglesplit"
      "SUPER, P, pseudo,"
      "SUPER, V, togglefloating,"
      "SUPER, F, fullscreen,"
      "SUPER, M, fullscreen, 1"

      "SUPER, left, movefocus, l"
      "SUPER, right, movefocus, r"
      "SUPER, up, movefocus, u"
      "SUPER, down, movefocus, d"

      "SUPER, 1, workspace, 1"
      "SUPER, 2, workspace, 2"
      "SUPER, 3, workspace, 3"
      "SUPER, 4, workspace, 4"
      "SUPER, 5, workspace, 5"
      "SUPER, 6, workspace, 6"
      "SUPER, 7, workspace, 7"
      "SUPER, 8, workspace, 8"
      "SUPER, 9, workspace, 9"
      "SUPER, 0, workspace, 10"

      "SUPER, comma, workspace, -1"
      "SUPER, period, workspace, +1"

      "SUPER SHIFT, 1, movetoworkspace, 1"
      "SUPER SHIFT, 2, movetoworkspace, 2"
      "SUPER SHIFT, 3, movetoworkspace, 3"
      "SUPER SHIFT, 4, movetoworkspace, 4"
      "SUPER SHIFT, 5, movetoworkspace, 5"
      "SUPER SHIFT, 6, movetoworkspace, 6"
      "SUPER SHIFT, 7, movetoworkspace, 7"
      "SUPER SHIFT, 8, movetoworkspace, 8"
      "SUPER SHIFT, 9, movetoworkspace, 9"
      "SUPER SHIFT, 0, movetoworkspace, 10"

      "SUPER SHIFT, left, swapwindow, l"
      "SUPER SHIFT, right, swapwindow, r"
      "SUPER SHIFT, up, swapwindow, u"
      "SUPER SHIFT, down, swapwindow, d"

      "SUPER ALT, right, movewindow, mon:+1"
      "SUPER ALT, left, movewindow, mon:-1"

      "SUPER, minus, resizeactive, -100 0"
      "SUPER, equal, resizeactive, 100 0"
      "SUPER SHIFT, minus, resizeactive, 0 -100"
      "SUPER SHIFT, equal, resizeactive, 0 100"

      "SUPER, mouse_down, workspace, e+1"
      "SUPER, mouse_up, workspace, e-1"

      "SUPER, S, togglespecialworkspace, magic"
      "SUPER SHIFT, S, movetoworkspace, special:magic"

      "SUPER CTRL, S, exec, hyprshot -m region"
      "SUPER CTRL, W, exec, hyprshot -m window -m active"
      ", Print, exec, hyprshot -m region"
      "CTRL, PRINT, exec, hyprshot -m output"

      "SUPER, PRINT, exec, hyprpicker -a"

      "CTRL SUPER, V, exec, kitty --title=clipse clipse"
      "CTRL SUPER, N, exec, kitty --title=nmtui nmtui"

      "ALT, Tab, exec, ${hyprswitch-pkg}/bin/hyprswitch gui --mod-key alt --key tab"
      "ALT SHIFT, Tab, exec, ${hyprswitch-pkg}/bin/hyprswitch gui --mod-key alt --key tab --reverse"

      "SUPER SHIFT, K, exec, ${shortcuts-popup}"
    ];

    bindrt = [
      "ALT, Tab, exec, ${hyprswitch-pkg}/bin/hyprswitch close --kill"
    ];

    bindm = [
      "SUPER, mouse:272, movewindow"
      "SUPER, mouse:273, resizewindow"
    ];

    bindel = [
      ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
      ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
      ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
      ",XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+"
      ",XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-"
    ];

    bindl = [
      ", XF86AudioNext, exec, playerctl next"
      ", XF86AudioPause, exec, playerctl play-pause"
      ", XF86AudioPlay, exec, playerctl play-pause"
      ", XF86AudioPrev, exec, playerctl previous"
    ];
  };
}
