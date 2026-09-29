# Home-manager module: houdt een ssh-tunnel open naar de linny-mcp-server op
# malandro, zodat lokale MCP-clients (Claude Code, Claude Desktop) hem op
# 127.0.0.1 kunnen bereiken.
#
# WAAROM EEN TUNNEL EN GEEN PUBLIEKE VHOST
#
# De publieke vhost bestond alleen voor custom connectors op claude.ai: die
# worden server-side door Anthropic opgehaald. Zolang de organisatie geen
# custom connectors toestaat is die route dicht en zijn alle clients lokaal.
#
# Een IP-filter op die vhost was geen alternatief. `linny-mcp.toorren.net` wijst
# naar het publieke adres, dus ook verkeer van het eigen netwerk gaat naar buiten
# en komt via de router terug; nginx ziet dan het WAN-adres en niet 192.168.2.x.
# Op lobos speelt daar bovenop een policy-route (tabel 51820) die verkeer naar
# dat publieke adres door de tn_arkana-tunnel stuurt -- lobos komt dus met wéér
# een ander adres binnen. Er bestaat in deze opstelling geen bronadres dat "LAN"
# betekent; alleen ssh-toegang tot malandro is een bruikbaar toegangsbewijs.
#
# Meegenomen voordeel: op 127.0.0.1 is de Host-header vanzelf loopback, dus de
# DNS-rebinding-bescherming van de MCP-SDK is tevreden zonder nginx-trucs.
# Zie docs/linny-mcp.md.
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.linny-mcp-tunnel;
in
{
  options.services.linny-mcp-tunnel = {
    enable = mkEnableOption "ssh-tunnel naar de linny-mcp-server";

    host = mkOption {
      type = types.str;
      default = "malandro";
      description = "ssh-doel; moet in ~/.ssh/config staan.";
    };

    sshAuthSock = mkOption {
      type = types.str;
      default = "%t/rbw/ssh-agent-socket";
      description = ''
        Pad naar de ssh-agent die de sleutel voor `host` levert (%t = XDG_RUNTIME_DIR).

        Moet expliciet: de systemd-user-manager erft `SSH_AUTH_SOCK` niet uit je
        shell, maar zet zelf `%t/gcr/ssh` (gnome-keyring). Die agent kent de
        malandro-sleutel niet en antwoordt "agent refused operation" -- een
        misleidende melding, want er ís een agent, alleen de verkeerde. De
        sleutels voor deze hosts komen uit rbw.
      '';
    };

    localPort = mkOption {
      type = types.port;
      default = 8096;
      description = "Lokale poort waarop de MCP-server verschijnt (127.0.0.1).";
    };

    remotePort = mkOption {
      type = types.port;
      default = 8096;
      description = "Poort waarop linny-mcp op de doelhost luistert.";
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.linny-mcp-tunnel = {
      Unit = {
        Description = "ssh-tunnel naar linny-mcp op ${cfg.host}";
        # `network-online.target` bestaat NIET in de user-manager -- zie de
        # opmerking in home/module/nextcloud-sync. Restart=always doet het werk.
      };

      Service = {
        # -N: geen remote command, alleen de forward.
        # ExitOnForwardFailure: zonder dit blijft ssh draaien terwijl de forward
        # mislukte (bijvoorbeeld omdat de poort lokaal al bezet is), en denkt
        # systemd dat alles goed gaat terwijl geen enkele client verbinding maakt.
        # ServerAlive*: een tunnel die stilvalt na suspend of een wifi-wissel
        # wordt zo binnen ~90s opgemerkt in plaats van eindeloos te hangen.
        ExecStart = concatStringsSep " " [
          "${pkgs.openssh}/bin/ssh"
          "-N"
          "-o ExitOnForwardFailure=yes"
          "-o ServerAliveInterval=30"
          "-o ServerAliveCountMax=3"
          "-o ConnectTimeout=10"
          "-L ${toString cfg.localPort}:127.0.0.1:${toString cfg.remotePort}"
          cfg.host
        ];
        # De sleutel voor malandro komt uit de rbw-agent. Staat die gelockt, dan
        # faalt ssh en probeert systemd het later opnieuw -- vandaar always en
        # geen start-limiet die na een paar pogingen opgeeft.
        Environment = [ "SSH_AUTH_SOCK=${cfg.sshAuthSock}" ];
        Restart = "always";
        RestartSec = 15;
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
