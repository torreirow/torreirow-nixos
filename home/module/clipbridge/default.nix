# Home-manager module: clipboard-bridge over ssh, zodat je een afbeelding op
# lobos kopieert en die met Ctrl+V in een Claude Code-sessie op een remote host
# plakt -- zonder X-forwarding.
#
# HOE CLAUDE CODE EEN AFBEELDING LEEST
#
# Bij Ctrl+V draait Claude Code (Linux) letterlijk:
#
#   xclip -selection clipboard -t TARGETS -o | grep image/… || wl-paste -l | grep image/…
#   xclip -selection clipboard -t image/png -o > f          || wl-paste --type image/png > f
#
# Op een headless host faalt xclip (geen DISPLAY), dus valt hij terug op
# `wl-paste`. Er hoeft alleen een `wl-paste` in de PATH te staan die het
# clipboard van lobos teruggeeft; WAYLAND_DISPLAY wordt niet gecontroleerd.
# Omdat PATH per aanroep wordt doorzocht, werkt dat ook in een Claude-sessie
# die al draaide vóór de shim er stond.
#
# TWEE KANTEN
#
#   serve (lobos):  systemd-user-socket %t/clipbridge.sock; per verbinding één
#                   regel verzoek → `wl-paste`. Plus een ssh-tunnel die die socket
#                   als `remoteSocket` op de doelhost zet (ssh -R).
#   shim (remote):  een `wl-paste` die via die socket vraagt.
#
# ALLEEN AFBEELDINGEN
#
# Zolang de tunnel staat kan elk proces van jou (en root) op de remote host de
# socket lezen. Daarom levert de handler alleen image/*-types en een gefilterde
# typelijst -- nooit tekst. Een gekopieerd wachtwoord (rbw!) lekt zo niet.
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.clipbridge;

  imageTypes = [ "image/png" "image/jpeg" "image/gif" "image/webp" "image/bmp" ];

  handler = pkgs.writeShellScript "clipbridge-handler" ''
    IFS= read -r req || exit 1
    case "$req" in
      targets)
        ${pkgs.wl-clipboard}/bin/wl-paste --list-types 2>/dev/null | ${pkgs.gnugrep}/bin/grep -E '^image/'
        ;;
      ${concatStringsSep "|" imageTypes})
        ${pkgs.wl-clipboard}/bin/wl-paste --no-newline --type "$req" 2>/dev/null
        ;;
    esac
    exit 0
  '';

  shim = pkgs.writeShellScriptBin "wl-paste" ''
    # clipbridge-shim: alleen `wl-paste -l` en `wl-paste --type <image/*>`.
    sock=${escapeShellArg cfg.shim.socket}
    [ -S "$sock" ] || exit 1
    case "$1" in
      -l|--list-types) req=targets ;;
      -t|--type) req="$2" ;;
      *) exit 1 ;;
    esac
    tmp=$(${pkgs.coreutils}/bin/mktemp) || exit 1
    trap '${pkgs.coreutils}/bin/rm -f "$tmp"' EXIT
    # Leeg antwoord = niet beschikbaar; Claude Code moet dan een exit-code ≠ 0 zien.
    printf '%s\n' "$req" \
      | ${pkgs.coreutils}/bin/timeout 30 ${pkgs.socat}/bin/socat -t 30 - "UNIX-CONNECT:$sock" > "$tmp" 2>/dev/null
    [ -s "$tmp" ] || exit 1
    ${pkgs.coreutils}/bin/cat "$tmp"
  '';
in
{
  options.services.clipbridge = {
    serve = {
      enable = mkEnableOption "clipboard van deze desktop via ssh -R aanbieden";

      host = mkOption {
        type = types.str;
        default = "malandro";
        description = "ssh-doel; moet in ~/.ssh/config staan.";
      };

      remoteSocket = mkOption {
        type = types.str;
        default = "/home/wtoorren/.cache/clipbridge.sock";
        description = "Absoluut pad van de socket op de doelhost (gelijk aan shim.socket daar).";
      };

      sshAuthSock = mkOption {
        type = types.str;
        default = "%t/rbw/ssh-agent-socket";
        description = "ssh-agent voor `host`; zie home/module/linny-mcp-tunnel waarom expliciet.";
      };
    };

    shim = {
      enable = mkEnableOption "`wl-paste`-shim die het clipboard via de clipbridge-socket leest";

      socket = mkOption {
        type = types.str;
        default = "${config.home.homeDirectory}/.cache/clipbridge.sock";
        description = "Socket die de tunnel vanaf de desktop hier neerzet.";
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.serve.enable {
      systemd.user.sockets.clipbridge = {
        Unit.Description = "Clipboard-bridge (alleen afbeeldingen) voor ssh -R";
        Socket = {
          ListenStream = "%t/clipbridge.sock";
          SocketMode = "0600";
          Accept = true;
        };
        Install.WantedBy = [ "sockets.target" ];
      };

      systemd.user.services."clipbridge@" = {
        Unit.Description = "Clipboard-bridge verzoek";
        Service = {
          ExecStart = "${handler}";
          StandardInput = "socket";
          StandardOutput = "socket";
          StandardError = "journal";
        };
      };

      systemd.user.services.clipbridge-tunnel = {
        Unit = {
          Description = "Clipboard-bridge naar ${cfg.serve.host}";
          Wants = [ "clipbridge.socket" ];
          After = [ "clipbridge.socket" ];
        };
        Service = {
          # Een achtergebleven socket van een vorige verbinding blokkeert -R
          # (sshd heeft StreamLocalBindUnlink standaard uit), dus eerst opruimen.
          ExecStartPre = "${pkgs.openssh}/bin/ssh -o ConnectTimeout=10 ${cfg.serve.host} rm -f ${escapeShellArg cfg.serve.remoteSocket}";
          ExecStart = concatStringsSep " " [
            "${pkgs.openssh}/bin/ssh"
            "-N"
            "-o ExitOnForwardFailure=yes"
            "-o ServerAliveInterval=30"
            "-o ServerAliveCountMax=3"
            "-o ConnectTimeout=10"
            "-R ${cfg.serve.remoteSocket}:%t/clipbridge.sock"
            cfg.serve.host
          ];
          Environment = [ "SSH_AUTH_SOCK=${cfg.serve.sshAuthSock}" ];
          Restart = "always";
          RestartSec = 15;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    })

    (mkIf cfg.shim.enable {
      home.packages = [ shim ];
    })
  ];
}
