{ pkgs, hyprquickframe-input, ... }:

let
  laptopMonitor = import ./laptop-monitor.nix;

  externalMonitors = pkgs.writeText "hyprland-external-monitors.json"
    (builtins.toJSON (import ./external-monitors.nix));

  # Schermstand-menu (SUPER+SHIFT+P): uitgebreid / klonen / alleen extern / alleen laptop.
  # Runtime via hyprctl keyword; niet onthouden (reload = weer uitgebreid). Eerst het scherm áán dat
  # blijft, dan pas het andere uit, zodat er nooit een moment zonder actieve output is.
  display-mode = pkgs.writeShellApplication {
    name = "hyprland-display-mode";
    runtimeInputs = [ pkgs.hyprland pkgs.jq pkgs.fuzzel pkgs.libnotify pkgs.coreutils ];
    text = ''
      monitors_all=$(hyprctl monitors all -j)
      ext=$(echo "$monitors_all" \
        | jq -r '[.[] | select(.name != "eDP-1" and (.name | test("^(HEADLESS|FALLBACK)") | not))] | first | .name // empty')

      if [ -z "$ext" ]; then
        notify-send -t 3000 "Schermstand" "Geen extern scherm aangesloten"
        exit 0
      fi

      # Regel voor het externe scherm: eigen mode/schaal als het een bekend scherm is (EDID-beschrijving),
      # anders preferred met schaal 1. Gelijk aan de regels in default.nix.
      desc=$(echo "$monitors_all" | jq -r --arg n "$ext" '.[] | select(.name == $n) | .description')
      ext_rule=$(jq -r --arg d "$desc" --arg n "$ext" \
        '(map(select(.desc == $d)) | .[0]) as $m
         | if $m then "\($n),\($m.mode),auto,\($m.scale)" else "\($n),preferred,auto,1" end' \
        ${externalMonitors})

      # Menu op elk actief, niet-gemirrord scherm. fuzzel neemt een lock per Wayland-sessie
      # ($XDG_RUNTIME_DIR/fuzzel-$WAYLAND_DISPLAY.lock); daarom krijgt elke instantie een eigen
      # runtime-dir met een symlink naar de echte socket. Eerste resultaat (keuze of Escape) wint.
      # Een nieuwe fuzzel pakt de toetsenbordfocus en de vorige sluit dan standaard af; daarom
      # --no-exit-on-keyboard-focus-loss, en het gefocuste scherm als laatste (krijgt het toetsenbord).
      # Onder $XDG_RUNTIME_DIR: kort pad (Unix-socketpad max 108 bytes) en alleen voor deze gebruiker.
      tmp=$(mktemp -d -p "$XDG_RUNTIME_DIR")
      trap 'rm -rf "$tmp"' EXIT
      pids=()
      for out in $(hyprctl monitors -j | jq -r '[.[] | select(.mirrorOf == "none")] | sort_by(.focused) | .[].name'); do
        mkdir "$tmp/$out"
        ln -s "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "$tmp/$out/$WAYLAND_DISPLAY"
        printf '%s\n' "󰍹  Uitgebreid" "󰍺  Klonen" "󰶐  Alleen extern" "󰌢  Alleen laptop" \
          | XDG_RUNTIME_DIR="$tmp/$out" fuzzel --dmenu --no-exit-on-keyboard-focus-loss --output "$out" --prompt "Scherm ($ext): " \
            > "$tmp/$out/choice" 2>/dev/null &
        pids+=("$!")
      done
      wait -n "''${pids[@]}" || true
      kill "''${pids[@]}" 2>/dev/null || true
      wait 2>/dev/null || true
      choice=$(cat "$tmp"/*/choice 2>/dev/null | head -n1)

      case "$choice" in
        *Uitgebreid)
          hyprctl keyword monitor "${laptopMonitor}"
          hyprctl keyword monitor "$ext_rule"
          ;;
        *Klonen)
          hyprctl keyword monitor "${laptopMonitor}"
          hyprctl keyword monitor "$ext_rule,mirror,eDP-1"
          ;;
        *"Alleen extern")
          hyprctl keyword monitor "$ext_rule"
          hyprctl keyword monitor "eDP-1,disable"
          ;;
        *"Alleen laptop")
          hyprctl keyword monitor "${laptopMonitor}"
          hyprctl keyword monitor "$ext,disable"
          ;;
        *) exit 0 ;;
      esac
    '';
  };

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

  hqf = hyprquickframe-input.packages.${pkgs.system}.default;

  font-scale = pkgs.writeShellScript "font-scale" ''
    current=$(${pkgs.glib}/bin/gsettings get org.gnome.desktop.interface text-scaling-factor)
    case "$1" in
      up)
        new=$(${pkgs.gawk}/bin/awk "BEGIN{x=$current+0.1; if(x>2.0) x=2.0; printf \"%.1f\", x}")
        ;;
      down)
        new=$(${pkgs.gawk}/bin/awk "BEGIN{x=$current-0.1; if(x<0.8) x=0.8; printf \"%.1f\", x}")
        ;;
      reset)
        new="1.0"
        ;;
      *)
        exit 1
        ;;
    esac
    ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface text-scaling-factor "$new"
    ${pkgs.libnotify}/bin/notify-send -t 1500 -h string:x-canonical-private-synchronous:font-scale "Tekstgrootte" "''${new}×"
  '';

  shortcuts-popup = pkgs.writeShellScript "shortcuts-popup" ''
    shortcuts=$(cat <<'SHORTCUTS'
    ─── Applicaties ──────────────────────────────────────────
    SUPER + Enter              Terminal
    SUPER + E                  Bestandsbeheer (Nautilus)
    SUPER + B                  Browser
    SUPER + SPACE              App launcher (walker)
    ─── Vensters ─────────────────────────────────────────────
    SUPER + Q / Backspace      Venster sluiten (Spotify: naar achtergrond)
    SUPER+SHIFT + Q            Spotify tonen/verbergen
    SUPER + V                  Zwevend venster aan/uit
    SUPER + F                  Volledig scherm
    SUPER + M                  Maximize
    SUPER + J                  Split richting wisselen
    SUPER + P                  Pseudo tiling
    SUPER + G                  Groep aan/uit
    SUPER + Tab                Volgend venster in groep
    SUPER+SHIFT + Tab          Vorig venster in groep
    ─── Focus ────────────────────────────────────────────────
    SUPER + ←/→/↑/↓            Focus verplaatsen
    SUPER+SHIFT + ←/→/↑/↓      Vensters wisselen
    ─── Workspaces ───────────────────────────────────────────
    SUPER + 1-0                Naar workspace 1-10
    SUPER + , / .              Vorige / volgende workspace
    SUPER+SHIFT + 1-0          Venster naar workspace
    SUPER + S                  Special workspace tonen
    SUPER+CTRL + S             Venster naar special workspace
    ─── Monitor ──────────────────────────────────────────────
    SUPER+ALT + ←/→            Venster naar andere monitor
    SUPER+SHIFT + P            Schermstand (uitgebreid/klonen/extern/laptop)
    ─── Venstergrootte ───────────────────────────────────────
    SUPER + - / =              100px smaller / breder
    SUPER+SHIFT + - / =        100px lager / hoger
    ─── Systeem ──────────────────────────────────────────────
    SUPER + L                  Scherm vergrendelen
    SUPER+SHIFT + L            Vergrendelen + slaapstand
    SUPER+SHIFT + Escape       Hyprland afsluiten
    ─── Screenshots ──────────────────────────────────────────
    SUPER+SHIFT + S            Screenshot (kies edit/save/copy)
    SUPER+SHIFT + W            Screenshot venster
    SUPER+SHIFT + C            Screenshot → klembord
    SUPER + Print              Kleurpicker
    ─── Tekstgrootte ─────────────────────────────────────────
    SUPER+CTRL+SHIFT + =       Tekst groter (+0.1)
    SUPER+CTRL+SHIFT + -       Tekst kleiner (-0.1)
    SUPER+CTRL+SHIFT + 0       Tekst reset (1.0×)
    ─── Diversen ─────────────────────────────────────────────
    SUPER+SHIFT + K            Sneltoetsen (dit scherm)
    CTRL+SUPER + C             Klembord history (fuzzel picker)
    CTRL+SUPER + N             Netwerk (nmtui)
    ALT + Tab                  Vensterlijst (walker)
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
      # Losse Super niet doorgeven aan apps. Mono (Subtitle Edit) vertaalt Super_L naar Keys.None, en
      # dat matcht elke lege SE-sneltoets: met de waveform open splitste Super de geselecteerde regel.
      # Combinaties (SUPER+x) blijven werken; de modifier-stand houdt Hyprland zelf bij.
      "SUPER, Super_L, exec, true"
      "SUPER, Super_R, exec, true"

      "SUPER, Return, exec, $terminal"
      "SUPER, E, exec, uwsm app -- nautilus"
      "SUPER, B, exec, $browser"

      "SUPER, SPACE, exec, uwsm app -- walker"
      "SUPER, Q, exec, ${smart-close}"
      "SUPER, Backspace, exec, ${smart-close}"
      "SUPER SHIFT, Q, togglespecialworkspace, spotify"

      "SUPER, L, exec, hyprlock"
      "SUPER SHIFT, L, exec, hyprlock & disown && systemctl suspend"
      "SUPER SHIFT, ESCAPE, exit,"

      "SUPER, J, layoutmsg, togglesplit"
      "SUPER, P, pseudo,"
      "SUPER SHIFT, P, exec, ${display-mode}/bin/hyprland-display-mode"
      "SUPER, V, togglefloating,"
      "SUPER, G, togglegroup,"
      "SUPER, Tab, changegroupactive, f"
      "SUPER SHIFT, Tab, changegroupactive, b"
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
      "SUPER CTRL, S, movetoworkspace, special:magic"

      "SUPER SHIFT, S, exec, ${hqf}/bin/hyprquickframe"
      "SUPER SHIFT, W, exec, env HQF_MODE=window ${hqf}/bin/hyprquickframe"
      "SUPER SHIFT, C, exec, env HQF_ACTION=temp ${hqf}/bin/hyprquickframe"

      "SUPER, PRINT, exec, hyprpicker -a"

      "CTRL SUPER, C, exec, cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"
      "CTRL SUPER, N, exec, alacritty --title nmtui -e nmtui"

      "ALT, Tab, exec, uwsm app -- walker -m windows"

      "SUPER SHIFT, K, exec, ${shortcuts-popup}"

      "SUPER CTRL SHIFT, equal, exec, ${font-scale} up"
      "SUPER CTRL SHIFT, minus, exec, ${font-scale} down"
      "SUPER CTRL SHIFT, 0,     exec, ${font-scale} reset"
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
