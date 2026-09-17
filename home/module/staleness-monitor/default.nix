# home-manager module: melden wanneer periodiek werk te lang niet is geslaagd
#
# Bewaakt per item de mtime van een stempelbestand -- het moment waarop dat werk
# voor het laatst is geslaagd -- en meldt via Signal zodra die te ver oploopt.
#
#   services.staleness-monitor = {
#     enable = true;
#     watch.nextcloud = {
#       stampFile = config.services.nextcloud-sync.stampFiles.docs;
#       message   = "Nextcloud-sync is te lang niet gelukt";
#       readinessCommand = "... curl status.php ...";
#     };
#   };
#
# WAAROM DIT BESTAAT, EN NIET EEN MELDING PER MISLUKTE RUN:
# de Nextcloud-server (bobadela1) gaat 's nachts uit om stroom te besparen en
# wordt 's ochtends handmatig gewekt. Een melding per mislukking gaf daardoor elke
# ochtend loos alarm: gemeten 2026-09-17 faalde de sync twee keer tussen het
# ontwaken van de laptop (06:24) en het wekken van de server (06:42), met twee
# Signal-berichten tot gevolg.
#
# Die mislukkingen hadden bovendien verschillende oorzaken -- een DNS-fout omdat
# lobos zelf nog geen netwerk had, en een 502 omdat de nginx vóór Nextcloud wél
# draaide maar de backend niet. Oorzaken uit elkaar houden is duur; de vraag "is
# er de afgelopen 24 uur uberhaupt gesynct?" is dat niet. Deze module meet dus het
# RESULTAAT en niet de storing, en is daarmee eenvoudiger dan het alternatief.
#
# TWEE DREMPELS:
#   leeftijd < softMaxAge              -> stil
#   softMaxAge <= leeftijd < hardMaxAge -> melden ALS readinessCommand slaagt
#   leeftijd >= hardMaxAge             -> altijd melden
#
# De zachte drempel met readiness voorkomt alarm in het ochtendgat waarin de
# server nog uit staat. De harde drempel dekt het omgekeerde geval: vergeet je de
# server dagen te wekken, dan is hij op geen enkel controlemoment bereikbaar en
# zou je zonder die tweede drempel nooit iets horen. Zonder readinessCommand
# vallen beide samen en is het gedrag een kale ouderdomscontrole.
#
# DIT IS GEEN DODEMANSKNOP: de monitor draait op dezelfde machine als het werk dat
# hij bewaakt. Valt lobos uit, dan zwijgt alles. Daarvoor zou een heartbeat naar
# een altijd-draaiende host nodig zijn (malandro). Bewust buiten scope.
{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.services.staleness-monitor;

  normalizePath = p:
    if p == "~" then config.home.homeDirectory
    else if hasPrefix "~/" p then "${config.home.homeDirectory}/${removePrefix "~/" p}"
    else p;

  watchModule = { name, ... }: {
    options = {
      stampFile = mkOption {
        type = types.str;
        example = literalExpression "config.services.nextcloud-sync.stampFiles.docs";
        description = ''
          Bestand waarvan de **mtime** het laatste geslaagde moment is. Een
          leidende `~/` wordt geëxpandeerd. Het bestand wordt bij activatie
          aangemaakt als het nog niet bestaat, zodat de teller bij installatie
          begint in plaats van meteen alarm te geven.
        '';
      };

      softMaxAge = mkOption {
        type = types.str;
        default = "24h";
        description = ''
          Vanaf deze leeftijd wordt er gemeld, maar alléén als
          `readinessCommand` slaagt. Als systemd-tijdspanne (`24h`, `90min`, …).
        '';
      };

      hardMaxAge = mkOption {
        type = types.str;
        default = "48h";
        description = ''
          Vanaf deze leeftijd wordt er altijd gemeld, ook als
          `readinessCommand` faalt of de onderliggende dienst onbereikbaar is.
          Moet minstens zo groot zijn als `softMaxAge`.
        '';
      };

      readinessCommand = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Shell-commando dat met exit 0 aangeeft dat de onderliggende dienst
          beschikbaar is. Bepaalt of er in het zachte venster gemeld wordt.

          Toets op **inhoud**, niet alleen op een statuscode: een captive portal
          geeft vrolijk HTTP 200 met HTML terug, en een reverse proxy antwoordt
          ook als de dienst erachter plat ligt (hier: 502).

          `null` laat het zachte venster samenvallen met de harde drempel.
        '';
      };

      message = mkOption {
        type = types.str;
        default = "Bewaking '${name}': te lang niet geslaagd";
        description = ''
          Eerste regel van de melding. De leeftijd en het laatste succesmoment
          worden er automatisch achter gezet.
        '';
      };
    };
  };

  # Vertaal een systemd-tijdspanne naar seconden. Gebeurt op bouwtijd, zodat het
  # script alleen nog met getallen werkt.
  toSeconds = span:
    let
      m = builtins.match " *([0-9]+) *(min|sec|s|m|h|d) *" span;
      multipliers = { s = 1; sec = 1; m = 60; min = 60; h = 3600; d = 86400; };
    in
    if m == null
    then throw "staleness-monitor: kan tijdspanne '${span}' niet lezen (gebruik bv. 24h, 90min, 3d)"
    else lib.toInt (elemAt m 0) * multipliers.${elemAt m 1};

  checkScript = pkgs.writeShellScript "staleness-check" ''
    set -uo pipefail
    export PATH=${makeBinPath [ pkgs.coreutils pkgs.bash ]}

    rc=0
    now=$(date +%s)

    # Eén functie per item, zodat een probleem bij het ene item de andere niet
    # blokkeert -- vandaar ook geen `set -e`.
    check() {
      name="$1"; stamp="$2"; soft="$3"; hard="$4"; msg="$5"; readiness="$6"

      if [ ! -r "$stamp" ]; then
        echo "staleness-monitor ($name): stempelbestand '$stamp' ontbreekt of is onleesbaar -- overgeslagen" >&2
        return 0
      fi

      mtime=$(stat -c %Y "$stamp" 2>/dev/null) || {
        echo "staleness-monitor ($name): mtime van '$stamp' niet te lezen -- overgeslagen" >&2
        return 0
      }
      age=$(( now - mtime ))
      human="$(date -d "@$mtime" '+%Y-%m-%d %H:%M')"
      hours=$(( age / 3600 ))

      if [ "$age" -lt "$soft" ]; then
        echo "staleness-monitor ($name): ''${hours}u oud, binnen de marge -- geen melding"
        return 0
      fi

      if [ "$age" -lt "$hard" ]; then
        if [ -n "$readiness" ]; then
          if ! bash -c "$readiness" >/dev/null 2>&1; then
            echo "staleness-monitor ($name): ''${hours}u oud, maar de dienst is niet beschikbaar -- geen melding"
            return 0
          fi
          echo "staleness-monitor ($name): ''${hours}u oud en de dienst is beschikbaar -- melden"
        else
          echo "staleness-monitor ($name): ''${hours}u oud (geen readiness-check) -- melden"
        fi
      else
        echo "staleness-monitor ($name): ''${hours}u oud, harde drempel voorbij -- melden"
      fi

      if ! ${cfg.sendCommand} "⏳ $msg
Laatste succes: $human (''${hours} uur geleden)."; then
        echo "staleness-monitor ($name): versturen van de melding mislukt" >&2
        return 1
      fi
    }

    ${concatStringsSep "\n" (mapAttrsToList (name: w: ''
      check ${escapeShellArg name} \
            ${escapeShellArg (normalizePath w.stampFile)} \
            ${toString (toSeconds w.softMaxAge)} \
            ${toString (toSeconds (if w.readinessCommand == null then w.softMaxAge else w.hardMaxAge))} \
            ${escapeShellArg w.message} \
            ${escapeShellArg (if w.readinessCommand == null then "" else w.readinessCommand)} || rc=1
    '') cfg.watch)}

    exit $rc
  '';

in
{
  options.services.staleness-monitor = {
    enable = mkEnableOption "dagelijkse melding wanneer periodiek werk te lang niet is geslaagd";

    checkTime = mkOption {
      type = types.str;
      default = "20:00";
      example = "*-*-* 13:00:00";
      description = ''
        Wanneer de controle draait, als `OnCalendar`-waarde. De timer staat op
        `Persistent=true`, dus een moment dat gemist werd doordat de machine
        sliep, wordt ingehaald zodra hij weer actief is.

        Het exacte tijdstip is minder kritisch dan het lijkt: valt de inhaalslag
        's ochtends terwijl de onderliggende dienst nog uit is, dan houdt de
        readiness-check het zachte venster stil.
      '';
    };

    sendCommand = mkOption {
      type = types.str;
      default = config.services.notify-signal.sendCommand;
      defaultText = literalExpression "config.services.notify-signal.sendCommand";
      description = ''
        Commando dat één argument neemt -- het bericht -- en dat verstuurt.
        Default is de verzender van `services.notify-signal`, zodat er één
        meldkanaal en één plek voor het token blijft.
      '';
    };

    watch = mkOption {
      type = types.attrsOf (types.submodule watchModule);
      default = { };
      description = ''
        Te bewaken items, per naam. Elk item wordt onafhankelijk beoordeeld:
        een ontbrekende stempel of een falend readiness-commando bij het ene
        item houdt de andere niet tegen.
      '';
    };
  };

  config = mkIf (cfg.enable && cfg.watch != { }) {
    # Zorg dat elk stempelbestand bestaat vanaf het moment dat de bewaking aan
    # gaat. Zonder dit zou een verse installatie meteen alarm geven, of -- bij de
    # omgekeerde keuze -- eeuwig zwijgen over werk dat nooit is geslaagd. Met dit
    # bestand is de betekenis eenduidig: "zo lang geleden is het voor het laatst
    # gelukt, of anders zo lang geleden is de bewaking ingesteld".
    home.activation.stalenessMonitorStamps =
      lib.hm.dag.entryAfter [ "writeBoundary" ] (
        concatStringsSep "\n" (mapAttrsToList (name: w:
          let f = normalizePath w.stampFile; in ''
            if [ ! -e ${escapeShellArg f} ]; then
              run mkdir -p ${escapeShellArg (builtins.dirOf f)}
              run touch ${escapeShellArg f}
            fi
          '') cfg.watch)
      );

    systemd.user.services.staleness-monitor = {
      Unit.Description = "Controle of periodiek werk recent nog geslaagd is";
      Service = {
        Type = "oneshot";
        ExecStart = "${checkScript}";
      };
    };

    systemd.user.timers.staleness-monitor = {
      Unit.Description = "Timer voor de staleness-controle";
      Timer = {
        OnCalendar = cfg.checkTime;
        # Haal een gemist moment in zodra de machine weer actief is -- een
        # slapende laptop zou anders controles gewoon overslaan.
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
