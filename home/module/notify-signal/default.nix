# home-manager module: faalmeldingen van user-services naar Signal
#
# Levert één template-unit `notify-signal@.service`. Hang die aan een unit via
# `Unit.OnFailure`, dan krijg je een Signal-bericht zodra die unit faalt:
#
#   systemd.user.services.foo.Unit.OnFailure = [ "notify-signal@%N.service" ];
#
# `%N` is de naam van de *falende* unit, dus één template bedient alles.
#
# Daarnaast is de verzender los beschikbaar als `sendCommand`, voor meldingen die
# géén unit-fout zijn (bv. de staleness-monitor). Zo blijft er één kanaal en één
# plek waar het token gelezen wordt.
#
# WAAROM VIA HOME ASSISTANT EN NIET DIRECT VIA signal-cli:
# de signal-cli REST API draait op malandro en luistert uitsluitend op
# 127.0.0.1:8088 -- vanaf lobos onbereikbaar. Het patroon uit
# modules/rustic-backup.nix (jq | curl naar die API) is daarom niet over te
# nemen. Home Assistant draait op dezelfde host, heeft `notify.signal_maria` al
# geconfigureerd, en is via HTTPS wél bereikbaar. Een SSH-hop naar malandro was
# het alternatief, maar die leunt op de rbw-agent: die kan gelockt zijn, en dan
# faalt juist de meldingsweg -- precies wat we proberen te repareren.
{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.services.notify-signal;

  # De verzender: neemt één bericht als argument en zet het op Signal. Bewust
  # losgetrokken van de faalmelding hieronder, zodat andere modules (bv.
  # staleness-monitor) hun eigen tekst kunnen sturen zonder het token opnieuw te
  # lezen of de curl-logica te dupliceren. Eén kanaal, één tokenlocatie.
  # Naar buiten beschikbaar als `services.notify-signal.sendCommand`.
  sendScript = pkgs.writeShellScript "notify-signal-send" ''
    set -u
    msg="''${1:-(leeg bericht)}"

    if [ ! -r ${escapeShellArg cfg.tokenFile} ]; then
      echo "notify-signal: token ${cfg.tokenFile} ontbreekt of is onleesbaar" >&2
      exit 1
    fi
    token="$(cat ${escapeShellArg cfg.tokenFile})"

    # --fail-with-body is essentieel: zonder --fail geeft curl exit 0 bij HTTP
    # 401/404/500, en dan zou een geweigerde melding er als geslaagd uitzien --
    # precies de stille storing die deze module moet voorkomen.
    if ! out=$(${pkgs.jq}/bin/jq -nc --arg m "$msg" '{message: $m}' \
      | ${pkgs.curl}/bin/curl -sS --fail-with-body --max-time 30 -X POST \
          "${cfg.homeAssistantUrl}/api/services/notify/${cfg.service}" \
          -H "Authorization: Bearer $token" \
          -H 'Content-Type: application/json' \
          --data @- 2>&1); then
      echo "notify-signal: versturen naar notify.${cfg.service} mislukt: $out" >&2
      exit 1
    fi
  '';

  # De faalmelding: bouwt de tekst voor een gecrashte unit en laat de verzender
  # het werk doen.
  notifyScript = pkgs.writeShellScript "notify-signal" ''
    set -u
    unit="''${1:-onbekend}"
    host="$(${pkgs.nettools}/bin/hostname)"

    # De laatste logregels meesturen scheelt een ssh-sessie om te achterhalen
    # wat er misging.
    detail="$(${pkgs.systemd}/bin/journalctl --user -u "$unit" -n 5 --no-pager -o cat 2>/dev/null | tail -n 5)"

    exec ${sendScript} "⚠️ $host: unit $unit gefaald.
$detail

Zie: journalctl --user -u $unit"
  '';

in
{
  options.services.notify-signal = {
    enable = mkEnableOption "faalmeldingen van systemd user-services naar Signal via Home Assistant";

    homeAssistantUrl = mkOption {
      type = types.str;
      default = "https://homeassistant.toorren.net";
      description = "Basis-URL van Home Assistant, zonder afsluitende slash.";
    };

    service = mkOption {
      type = types.str;
      default = "signal_maria";
      description = ''
        De notify-dienst in Home Assistant, zonder het `notify.`-voorvoegsel.
        Beschikbaar op deze installatie: `signal_maria` (Signal) en `wouter`
        (Telegram).
      '';
    };

    sendCommand = mkOption {
      type = types.str;
      readOnly = true;
      default = "${sendScript}";
      defaultText = literalExpression "<het gegenereerde verzendscript>";
      description = ''
        Pad naar een script dat één argument neemt -- het bericht -- en dat via
        Home Assistant naar Signal stuurt. Read-only; bedoeld voor andere modules
        die een melding willen sturen die géén unit-fout is, zonder het token
        opnieuw te lezen of de curl-logica te dupliceren:

        ```nix
        ExecStart = "''${config.services.notify-signal.sendCommand} 'er is iets aan de hand'";
        ```

        Eindigt met een foutstatus als het token onleesbaar is of als Home
        Assistant het bericht weigert.
      '';
    };

    tokenFile = mkOption {
      type = types.str;
      default = "/run/secrets/ha-token";
      description = ''
        Bestand met een Home Assistant long-lived access token. Wordt door
        agenix neergezet (`age.secrets.ha-token` in `hosts/lobos/lobos-secrets.nix`),
        eigenaar `wtoorren`, mode 0400. Bewust niet in de nix-store.
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services."notify-signal@" = {
      Unit.Description = "Signal-melding dat %i gefaald is";
      Service = {
        Type = "oneshot";
        ExecStart = "${notifyScript} %i";
      };
    };
  };
}
