# podrec start|stop|status: neemt "Podcast mic 1" en "Podcast mic 2" op als twee losse
# FLAC-bestanden (mono, 24-bit) in ~/Podcast/<datum>_<tijd>/. Zie docs/podcast-mpenzi.md.
#
# Eén opname van de stereobron podcast-2mics, bij stop gesplitst: twee losse pw-records starten
# tot ~0,2 s na elkaar en lopen dan in de montage niet gelijk.

mics=(podcast-mic-1 podcast-mic-2)
labels=("Podcast mic 1" "Podcast mic 2")
target_root=${PODREC_DIR:-$HOME/Podcast}
state_dir=${XDG_RUNTIME_DIR:-/tmp/podrec-$UID}/podrec
state=$state_dir/state

# Elke melding ook als notificatie: podrec start meestal vanuit het menu, zonder terminal.
say() {
  echo "podrec: $1"
  notify-send -a Podcast -i audio-input-microphone "Podcast" "$1" 2>/dev/null || true
}

fail() {
  echo "podrec: $1" >&2
  notify-send -a Podcast -u critical -i dialog-error "Podcast" "$1" 2>/dev/null || true
  exit 1
}

# Draait dit pid nog, en is het onze opnemer (niet een hergebruikt pid)?
alive() {
  [[ -n "$1" && -d "/proc/$1" ]] || return 1
  [[ "$(cat "/proc/$1/comm" 2>/dev/null || true)" == pw-record ]]
}

load_state() {
  [[ -f "$state" ]] || return 1
  { read -r dir; read -r pid; } < "$state" || return 1
  [[ -n "$dir" ]]
}

# SIGINT, niet SIGTERM: daarop sluit pw-record het bestand netjes af.
stop_one() {
  local pid=$1 waited=0
  alive "$pid" || return 0
  kill -INT "$pid" 2>/dev/null || true
  while [[ -d "/proc/$pid" ]] && (( waited < 50 )); do
    sleep 0.1
    waited=$((waited + 1))
  done
  if [[ -d "/proc/$pid" ]]; then
    echo "podrec: opnemer $pid reageert niet op SIGINT, hard afgebroken" >&2
    kill -KILL "$pid" 2>/dev/null || true
  fi
}

cmd_start() {
  if load_state; then
    if alive "$pid"; then
      fail "Er loopt al een opname (in $dir). Stop die eerst."
    fi
    rm -f "$state"
  fi

  local nodes missing=()
  nodes=$(pw-dump | jq -r '.[].info.props["node.name"]? // empty')
  for i in 0 1; do
    grep -qxF "${mics[i]}" <<< "$nodes" || missing+=("${labels[i]}")
  done
  # De stereobron komt uit de PipeWire-config; een draaiende PipeWire leest die pas na een
  # herstart (uit- en inloggen is niet genoeg: de systemd-gebruikerssessie blijft doorlopen).
  if (( ${#missing[@]} == 0 )) && ! grep -qxF podcast-2mics <<< "$nodes"; then
    fail "Podcast (2 mics) ontbreekt. Herstart de laptop en probeer opnieuw."
  fi
  if (( ${#missing[@]} == 1 )); then
    fail "${missing[0]} niet gevonden. Zit hij in de juiste USB-poort (rechts)? Geen opname gestart."
  elif (( ${#missing[@]} == 2 )); then
    fail "Podcast mic 1 en Podcast mic 2 niet gevonden. Zitten ze in de USB-poorten rechts? Geen opname gestart."
  fi

  dir=$target_root/$(date +%Y-%m-%d_%H%M%S)
  mkdir -p "$dir"
  # HUP negeren vóór de exec: de opname overleeft het sluiten van een terminal.
  ( trap '' HUP; exec pw-record --target podcast-2mics --channels 2 --rate 48000 --format s24 \
      "$dir/.opname.flac" ) > "$dir/.opname.log" 2>&1 &
  pid=$!
  mkdir -p "$state_dir"
  printf '%s\n%s\n' "$dir" "$pid" > "$state"

  sleep 1
  if ! alive "$pid"; then
    rm -f "$state"
    fail "Opname kon niet starten; zie $dir/.opname.log."
  fi
  say "Opname gestart. Stoppen via het menu: Podcast opname stoppen."
}

cmd_stop() {
  if ! load_state; then
    say "Er loopt geen opname."
    return 0
  fi
  stop_one "$pid"
  rm -f "$state"
  # Links = mic 1, rechts = mic 2 (zie combine-stream in default.nix).
  if [[ -s "$dir/.opname.flac" ]] \
    && sox "$dir/.opname.flac" "$dir/mic1.flac" remix 1 \
    && sox "$dir/.opname.flac" "$dir/mic2.flac" remix 2; then
    rm -f "$dir/.opname.flac" "$dir/.opname.log"
    say "Opname opgeslagen in $dir"
  else
    fail "Opname gestopt, maar splitsen mislukte; de ruwe opname staat in $dir/.opname.flac."
  fi
}

cmd_status() {
  if load_state && alive "$pid"; then
    echo "podrec: opname loopt in $dir"
  else
    echo "podrec: geen opname"
  fi
}

case "${1:-}" in
  start) cmd_start ;;
  stop) cmd_stop ;;
  status) cmd_status ;;
  *) echo "gebruik: podrec start|stop|status" >&2; exit 2 ;;
esac
