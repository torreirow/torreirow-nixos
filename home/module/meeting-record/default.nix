# home-manager module: meeting-opname (Teams / Slack / Jitsi) op lobos
#
# Een gesprek bestaat uit twee stromen die elkaar nooit raken: wat de anderen
# zeggen gaat naar de sink, wat jij zegt gaat de app in en komt daar niet terug
# (dat zou echoen). Eén opnamepunt kan dus nooit beide kanten vangen.
#
#   anderen  <- monitor van de huidige default sink   -> anderen.wav
#   ik       <- de huidige default source (microfoon) -> ik.wav
#
# Twee losse sporen, nooit live gemengd. Dat kost niets -- twee `pw-record`-
# processen blijven op ~11 ms constante offset zonder drift, want PipeWire
# hersamplet elk apparaat naar één grafiekklok (gemeten, zie design.md) -- en
# het levert drie dingen op: niveaus achteraf corrigeerbaar, echo-op-speakers
# achteraf te redden, en whisper leest de sporen los, dus sprekerscheiding
# zonder diarisatiemodel.
#
# Er staan bewust geen apparaatnamen of node-id's in dit script. De inkomende
# stream draagt `stream.capture.sink=true`, waarna WirePlumber hem zelf aan de
# monitor van de *huidige* default sink koppelt; de mic-stream krijgt de default
# source. Beide verhuizen dus mee als je van apparaat wisselt -- op deze host
# geen luxe, met vijf sinks, een Bluetooth-headset en `hosts/lobos/midi.nix`
# dat de default actief omzet.
#
# Wat deze module NIET doet: uit zichzelf opnemen. `meetrec start` is altijd een
# expliciete handeling; er is geen timer en geen dienst. Automatische
# call-detectie is bewust buiten scope gehouden (bean nixos-js5l).
{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.services.meeting-record;

  # Expandeer een leidende ~ naar de absolute home-dir.
  normalizePath = p:
    if p == "~" then config.home.homeDirectory
    else if hasPrefix "~/" p then "${config.home.homeDirectory}/${removePrefix "~/" p}"
    else p;

  targetDir = normalizePath cfg.targetDir;
  stateDir = "${config.home.homeDirectory}/.local/state/meeting-record";

  mergeScript = ./merge-transcripts.py;

  # lib.escapeShellArg laat "veilige" strings ongequoteerd staan, waardoor
  # bijvoorbeeld `WHISPER_LANGUAGE=nl` ontstaat -- en `nl` is een commando, dus
  # shellcheck (SC2209) breekt de build. Altijd quoten dus.
  shq = s: "'" + replaceStrings [ "'" ] [ "'\\''" ] (toString s) + "'";

  meetrec = pkgs.writeShellApplication {
    name = "meetrec";

    # whisper zit hier bewust NIET in: dat is een closure van honderden MB's die
    # je alleen bij `transcribe` nodig hebt. writeShellApplication laat $PATH
    # intact, dus het commando uit systemPackages wordt gewoon gevonden.
    runtimeInputs = with pkgs; [
      pipewire
      ffmpeg-full
      coreutils
      gawk
      util-linux
      python3
    ];

    text = ''
      TARGET_DIR=${shq targetDir}
      STATE_DIR=${shq stateDir}
      STATE_FILE="$STATE_DIR/current"
      OPUS_BITRATE=${shq cfg.opusBitrate}
      OPUS_CHANNELS=${shq cfg.opusChannels}
      MIX_WEIGHTS=${shq cfg.mixWeights}
      WHISPER_CMD=${shq cfg.whisperCommand}
      WHISPER_MODEL=${shq cfg.whisperModel}
      WHISPER_LANGUAGE=${shq cfg.whisperLanguage}
      WANT_INCOMING=${if cfg.incoming.enable then "1" else "0"}
      WANT_MIC=${if cfg.mic.enable then "1" else "0"}

      # Markernamen in de PipeWire-grafiek. Ze doen twee dingen: `meetrec status`
      # kan er de daadwerkelijke bron mee opzoeken, en ze maken in `pw-link -l`
      # meteen zichtbaar waar een opname aan hangt.
      NODE_INCOMING=meetrec-incoming
      NODE_MIC=meetrec-mic

      die() {
        echo "meetrec: $*" >&2
        exit 1
      }

      usage() {
        cat <<'USAGE'
      meetrec -- neemt beide kanten van een gesprek op als twee gescheiden sporen

        meetrec start [naam]       begin een opname (map krijgt datum + tijd + naam)
        meetrec stop               stop, comprimeer naar Opus en ruim de WAV's op
        meetrec status             loopt er iets, sinds wanneer, aan welke bronnen
        meetrec list               afgeronde opnames
        meetrec mix [map]          voeg de twee sporen samen tot één bestand
        meetrec transcribe [map]   whisper per spoor + samengevoegd transcript

      Zonder [map] pakken mix en transcribe de nieuwste opname.
      USAGE
      }

      # --- staat -------------------------------------------------------------
      # Vier regels in vaste volgorde; geen `source`, zodat een pad met rare
      # tekens niets kan uitvoeren.
      REC_DIR=""
      REC_STARTED=""
      PID_IN=""
      PID_MIC=""

      load_state() {
        [ -f "$STATE_FILE" ] || return 1
        { read -r REC_DIR; read -r REC_STARTED; read -r PID_IN; read -r PID_MIC; } < "$STATE_FILE" || return 1
        [ -n "$REC_DIR" ]
      }

      save_state() {
        mkdir -p "$STATE_DIR"
        printf '%s\n%s\n%s\n%s\n' "$1" "$2" "$3" "$4" > "$STATE_FILE"
      }

      # Draait dit pid nog, en is het echt ónze opnemer? Een kale `kill -0` zou
      # na pid-hergebruik een willekeurig ander proces gezond verklaren.
      alive() {
        [ -n "$1" ] || return 1
        [ -d "/proc/$1" ] || return 1
        [ "$(cat "/proc/$1/comm" 2>/dev/null || true)" = "pw-record" ]
      }

      # Aan welke bron hangt een opnamestream op dit moment?
      peers_of() {
        pw-link -l 2>/dev/null | awk -v node="$1" '
          /^[^[:space:]]/ { inblock = ($0 ~ "^" node ":"); next }
          inblock && /\|<-/ {
            sub(/.*\|<-[[:space:]]*/, "")
            sub(/:[^:]*$/, "")
            print
          }
        ' | sort -u
      }

      human_size() {
        if [ -f "$1" ]; then
          du -h "$1" | cut -f1
        else
          echo "-"
        fi
      }

      duration_of() {
        ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$1" 2>/dev/null || true
      }

      # --- opname ------------------------------------------------------------
      # `trap ''' HUP` vóór de exec: een genegeerde signaaldispositie overleeft
      # execve, dus de opnemer blijft draaien als je de terminal sluit. Zonder
      # dit sterft je opname zodra het venster dichtgaat.
      spawn_recorder() {
        local props="$1" channels="$2" outfile="$3" logfile="$4"
        ( trap ''' HUP; exec pw-record -P "$props" --channels "$channels" "$outfile" ) \
          >"$logfile" 2>&1 &
        echo $!
      }

      cmd_start() {
        local label="''${1:-}"

        if load_state; then
          if alive "$PID_IN" || alive "$PID_MIC"; then
            die "er loopt al een opname in $REC_DIR -- stop die eerst met 'meetrec stop'"
          fi
          echo "meetrec: oude opnamestaat opgeruimd (de processen draaiden niet meer)" >&2
          rm -f "$STATE_FILE"
        fi

        [ "$WANT_INCOMING" = 1 ] || [ "$WANT_MIC" = 1 ] \
          || die "zowel incoming als mic staan uit -- er valt niets op te nemen"

        local dir
        dir="$TARGET_DIR/$(date +%Y-%m-%d-%H%M)"
        if [ -n "$label" ]; then
          # Alles wat geen letter, cijfer, streepje of underscore is eruit: de
          # naam wordt een mapnaam.
          label=$(printf '%s' "$label" | tr -c 'A-Za-z0-9_-' '-' | sed 's/-\+/-/g; s/^-//; s/-$//')
          if [ -n "$label" ]; then
            dir="$dir-$label"
          fi
        fi
        if [ -e "$dir" ]; then
          dir="$dir-$(date +%S)"
        fi
        mkdir -p "$dir"

        local pid_in="" pid_mic=""
        if [ "$WANT_INCOMING" = 1 ]; then
          pid_in=$(spawn_recorder \
            "{ stream.capture.sink=true node.name=$NODE_INCOMING }" \
            2 "$dir/anderen.wav" "$dir/.anderen.log")
        fi
        if [ "$WANT_MIC" = 1 ]; then
          pid_mic=$(spawn_recorder \
            "{ node.name=$NODE_MIC }" \
            1 "$dir/ik.wav" "$dir/.ik.log")
        fi

        save_state "$dir" "$(date +%s)" "$pid_in" "$pid_mic"
        load_state

        # Even wachten tot WirePlumber de streams gekoppeld heeft, anders meldt
        # `status` direct erna nog geen bron.
        sleep 1

        echo "meetrec: opname gestart in $dir"
        report_tracks
      }

      report_tracks() {
        local name pid peers
        for name in incoming mic; do
          if [ "$name" = incoming ]; then
            pid="$PID_IN"
            [ -n "$pid" ] || continue
            peers=$(peers_of "$NODE_INCOMING")
            printf '  anderen  pid %-7s %s\n' "$pid" "''${peers:-(nog niet gekoppeld)}"
          else
            pid="$PID_MIC"
            [ -n "$pid" ] || continue
            peers=$(peers_of "$NODE_MIC")
            printf '  ik       pid %-7s %s\n' "$pid" "''${peers:-(nog niet gekoppeld)}"
          fi
        done
      }

      # SIGINT, niet SIGTERM: pw-record sluit daarop de WAV netjes af en schrijft
      # de header weg. De exitcode is dan nonzero -- dat is géén fout, dus we
      # toetsen op het bestand, niet op de status.
      stop_one() {
        local pid="$1"
        [ -n "$pid" ] || return 0
        alive "$pid" || return 0
        kill -INT "$pid" 2>/dev/null || true
        local waited=0
        while [ -d "/proc/$pid" ] && [ "$waited" -lt 50 ]; do
          sleep 0.1
          waited=$((waited + 1))
        done
        if [ -d "/proc/$pid" ]; then
          echo "meetrec: opnemer $pid reageert niet op SIGINT, hard afgebroken" >&2
          kill -KILL "$pid" 2>/dev/null || true
        fi
      }

      encode_track() {
        local wav="$1" opus="$2"
        nice -n 15 ionice -c3 ffmpeg -nostdin -v error -y \
          -i "$wav" -c:a libopus -b:a "$OPUS_BITRATE" -ac "$OPUS_CHANNELS" "$opus"
      }

      cmd_stop() {
        load_state || die "er loopt geen opname"

        stop_one "$PID_IN"
        stop_one "$PID_MIC"

        local rc=0 track wav opus dur
        for track in anderen ik; do
          wav="$REC_DIR/$track.wav"
          [ -f "$wav" ] || continue
          opus="$REC_DIR/$track.opus"

          dur=$(duration_of "$wav")
          if [ -z "$dur" ]; then
            echo "meetrec: $wav is onleesbaar, niet gecomprimeerd" >&2
            rc=1
            continue
          fi

          # Comprimeren pas nu, met verlaagde prioriteit: tijdens het gesprek zou
          # een encoder rechtstreeks met de call concurreren.
          if encode_track "$wav" "$opus"; then
            rm -f "$wav"
            printf '  %-8s %8ss  %s\n' "$track" "''${dur%%.*}" "$(human_size "$opus")"
          else
            echo "meetrec: comprimeren van $wav mislukt -- WAV blijft staan" >&2
            rc=1
          fi
        done

        rm -f "$STATE_FILE" "$REC_DIR/.anderen.log" "$REC_DIR/.ik.log"
        echo "meetrec: opname afgerond in $REC_DIR"
        return "$rc"
      }

      cmd_status() {
        if ! load_state; then
          echo "meetrec: geen opname bezig."
          return 0
        fi

        local running=0
        if alive "$PID_IN"; then running=1; fi
        if alive "$PID_MIC"; then running=1; fi

        if [ "$running" = 0 ]; then
          echo "meetrec: opname geregistreerd in $REC_DIR, maar er draait geen enkele opnemer."
          echo "         'meetrec stop' rondt af wat er is."
          return 1
        fi

        local now elapsed
        now=$(date +%s)
        elapsed=$((now - REC_STARTED))
        printf 'meetrec: opname loopt in %s (%02d:%02d:%02d)\n' \
          "$REC_DIR" $((elapsed / 3600)) $(((elapsed % 3600) / 60)) $((elapsed % 60))

        local track pid label peers
        for track in anderen ik; do
          if [ "$track" = anderen ]; then
            pid="$PID_IN"; label="$NODE_INCOMING"
          else
            pid="$PID_MIC"; label="$NODE_MIC"
          fi
          [ -n "$pid" ] || continue
          if alive "$pid"; then
            peers=$(peers_of "$label")
            printf '  %-8s %6s  pid %-7s %s\n' \
              "$track" "$(human_size "$REC_DIR/$track.wav")" "$pid" \
              "''${peers:-(niet gekoppeld)}"
          else
            printf '  %-8s %6s  OMGEVALLEN (pid %s draait niet meer)\n' \
              "$track" "$(human_size "$REC_DIR/$track.wav")" "$pid"
          fi
        done
      }

      cmd_list() {
        [ -d "$TARGET_DIR" ] || { echo "meetrec: nog geen opnames in $TARGET_DIR"; return 0; }
        local found=0 dir
        while IFS= read -r dir; do
          [ -n "$dir" ] || continue
          found=1
          local bits=""
          if [ -f "$dir/anderen.opus" ]; then bits="$bits anderen"; fi
          if [ -f "$dir/ik.opus" ]; then bits="$bits ik"; fi
          if [ -f "$dir/meeting.opus" ]; then bits="$bits mix"; fi
          if [ -f "$dir/transcript.txt" ]; then bits="$bits transcript"; fi
          if [ -z "$bits" ]; then bits=" (leeg)"; fi
          printf '  %-28s %s\n' "$(basename "$dir")" "''${bits# }"
        done < <(find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
        [ "$found" = 1 ] || echo "meetrec: nog geen opnames in $TARGET_DIR"
      }

      # Zonder argument: de nieuwste opname.
      resolve_dir() {
        local given="''${1:-}"
        if [ -n "$given" ]; then
          [ -d "$given" ] || die "$given bestaat niet"
          printf '%s' "$given"
          return 0
        fi
        local newest
        newest=$(find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1)
        [ -n "$newest" ] || die "geen opnames gevonden in $TARGET_DIR"
        printf '%s' "$newest"
      }

      cmd_mix() {
        local dir
        dir=$(resolve_dir "''${1:-}")
        local a="$dir/anderen.opus" b="$dir/ik.opus" out="$dir/meeting.opus"
        [ -f "$a" ] || die "$a ontbreekt (is de opname al gestopt?)"
        [ -f "$b" ] || die "$b ontbreekt (is de opname al gestopt?)"

        # normalize=0 houdt de niveaus zoals ze zijn; met normalize=1 halveert
        # ffmpeg beide kanten en wordt alles zacht. De balans regel je met
        # mixWeights, want je eigen stem staat doorgaans veel harder dan de
        # inkomende kant.
        nice -n 15 ionice -c3 ffmpeg -nostdin -v error -y -i "$a" -i "$b" \
          -filter_complex "[0:a][1:a]amix=inputs=2:duration=longest:normalize=0:weights=$MIX_WEIGHTS" \
          -c:a libopus -b:a "$OPUS_BITRATE" "$out" \
          || die "mixen mislukt"

        echo "meetrec: $out geschreven ($(human_size "$out")) -- de losse sporen blijven staan"
      }

      cmd_transcribe() {
        local dir
        dir=$(resolve_dir "''${1:-}")
        command -v "$WHISPER_CMD" >/dev/null 2>&1 \
          || die "$WHISPER_CMD niet gevonden -- staat openai-whisper wel in systemPackages?"

        local track found=0
        local args=()
        for track in anderen ik; do
          [ -f "$dir/$track.opus" ] || continue
          found=1
          args=(--model "$WHISPER_MODEL" --output_format srt --output_dir "$dir")
          if [ -n "$WHISPER_LANGUAGE" ]; then
            args+=(--language "$WHISPER_LANGUAGE")
          fi
          echo "meetrec: transcriberen van $track.opus ..."
          nice -n 15 ionice -c3 "$WHISPER_CMD" "$dir/$track.opus" "''${args[@]}" \
            || die "whisper faalde op $track.opus"
        done
        [ "$found" = 1 ] || die "geen .opus-sporen in $dir -- is de opname gestopt?"

        python3 ${mergeScript} \
          --track "ik=$dir/ik.srt" \
          --track "anderen=$dir/anderen.srt" \
          --output "$dir/transcript.txt"
      }

      main() {
        local cmd=status
        if [ "$#" -gt 0 ]; then
          cmd="$1"
          shift
        fi
        case "$cmd" in
          start)      cmd_start "''${1:-}" ;;
          stop)       cmd_stop ;;
          status)     cmd_status ;;
          list)       cmd_list ;;
          mix)        cmd_mix "''${1:-}" ;;
          transcribe) cmd_transcribe "''${1:-}" ;;
          -h|--help|help) usage ;;
          *)          usage >&2; die "onbekend commando: $cmd" ;;
        esac
      }

      main "$@"
    '';
  };

in
{
  options.services.meeting-record = {
    enable = mkEnableOption "meetrec: opname van beide kanten van een gesprek (Teams/Slack/Jitsi)";

    targetDir = mkOption {
      type = types.str;
      default = "~/Meetings";
      description = ''
        Basismap waaronder elke opname een eigen map `YYYY-MM-DD-HHMM[-naam]` krijgt.
        Een leidende `~/` wordt geëxpandeerd.
      '';
    };

    incoming.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Neem de inkomende audio op: de monitor van de *huidige* default sink, via
        `stream.capture.sink=true`. Daar loopt ook je overige systeemgeluid door
        (muziek, notificaties, een Signal-belletje) -- dat is de prijs voor een
        opname die geen apparaatnamen hoeft te kennen en een device-wissel overleeft.
      '';
    };

    mic.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Neem de eigen microfoon op: de huidige default source, mono. Zet je dit
        uit, dan houd je alleen "iedereen behalve jij" over -- meeting-apps spelen
        je eigen mic niet terug naar de sink.
      '';
    };

    opusBitrate = mkOption {
      type = types.str;
      default = "32k";
      description = ''
        Bitrate voor de Opus-encoding bij `meetrec stop`. 32k mono is ruim voldoende
        voor spraak (~15 MB/uur per spoor tegen ~350 MB/uur rauw) en meteen wat
        whisper wil.
      '';
    };

    opusChannels = mkOption {
      type = types.ints.between 1 2;
      default = 1;
      description = ''
        Kanalen in de gecomprimeerde sporen. Mono is de juiste keuze voor spraak;
        zet dit op 2 als een gedeeld scherm met muziek of video ertoe doet.
      '';
    };

    mixWeights = mkOption {
      type = types.str;
      default = "1 1";
      example = "1 0.6";
      description = ''
        Gewichten voor `ffmpeg amix` bij `meetrec mix`, in de volgorde
        `anderen ik`. Je eigen stem staat doorgaans veel harder dan de inkomende
        kant; met bijvoorbeeld `1 0.6` trek je dat recht.
      '';
    };

    whisperCommand = mkOption {
      type = types.str;
      default = "whisper";
      description = ''
        Commando voor transcriptie, gezocht op `$PATH`. Bewust geen pakket-optie:
        whisper is een closure van honderden MB's die je alleen bij `transcribe`
        nodig hebt, en `openai-whisper` staat al in `hosts/lobos/programs.nix`.

        `whisper-cpp` en `whisper-ctranslate2` zitten ook in nixpkgs en zijn op CPU
        een andere orde -- meten, niet aannemen.
      '';
    };

    whisperModel = mkOption {
      type = types.str;
      default = "turbo";
      description = "Whisper-model. `turbo` is de standaard van openai-whisper zelf.";
    };

    whisperLanguage = mkOption {
      type = types.str;
      default = "nl";
      description = ''
        Taal die aan whisper wordt doorgegeven. Leeg laten betekent: whisper laten
        raden.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ meetrec ];
  };
}
