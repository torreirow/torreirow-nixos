#!/usr/bin/env bash
#
# vaultwarden-restoretest.sh — herhaalbare, non-destructieve restore-test van de
# rustic S3-backup van Vaultwarden.
#
#   (default)        restore uit S3 -> reassemble (dump wordt db.sqlite3) ->
#                    wegwerp-container op 127.0.0.1:8099 -> curl /alive + sqlite-tellingen
#   --rbw            + geïsoleerde rbw-crypto-test: login met echte master-password
#                    en TOTP tegen de gerestorede instance -> bewijst dat de vault
#                    daadwerkelijk ontsleutelt. Raakt de echte rbw-config NIET aan.
#   --snapshot <id>  welke rustic-snapshot (default: latest)
#   --keep           laat container + data staan na afloop (voor handmatig snuffelen)
#   --destroy        ruim alle test-resources op en stop
#   --help
#
# Draai als je normale user (wtoorren); het script sudo't alleen de rustic-restore
# en docker. Zie openspec .../add-vaultwarden-restore-test voor de onderbouwing.

set -euo pipefail

########## Vaste resources ##########
WORK="/tmp/vw-restoretest"
CONTAINER="vaultwarden-restoretest"
HOST="127.0.0.1"
PORT="8099"
IMAGE="vaultwarden/server:latest"
PROFILE="malandro"
PINENTRY="/run/current-system/sw/bin/pinentry-tty"

# Geïsoleerde XDG-omgeving voor rbw (eigen config + eigen rbw-agent onder $WORK)
RBW_HOME="$WORK/rbwhome"
export_rbw_env() {
  export XDG_CONFIG_HOME="$RBW_HOME/config"
  export XDG_CACHE_HOME="$RBW_HOME/cache"
  export XDG_DATA_HOME="$RBW_HOME/data"
  export XDG_STATE_HOME="$RBW_HOME/state"
  export XDG_RUNTIME_DIR="$RBW_HOME/run"
}

########## Opties ##########
DO_RBW=0
KEEP=0
DESTROY=0
SNAPSHOT="latest"

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --rbw)      DO_RBW=1 ;;
    --keep)     KEEP=1 ;;
    --destroy)  DESTROY=1 ;;
    --snapshot) shift; SNAPSHOT="${1:?--snapshot vereist een id}" ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "Onbekende optie: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '  \033[1;32m✓\033[0m %s\n' "$*"; }
fail() { printf '  \033[1;31m✗\033[0m %s\n' "$*" >&2; }

########## Teardown ##########
teardown() {
  export_rbw_env
  rbw stop-agent            >/dev/null 2>&1 || true
  sudo docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  sudo rm -rf "$WORK"       2>/dev/null || true
}

if [ "$DESTROY" -eq 1 ]; then
  log "Opruimen van restore-test resources"
  teardown
  ok "Container, werkmap en geïsoleerde rbw-agent verwijderd (idempotent)"
  exit 0
fi

# Faalveilige teardown: bij een fout (of normaal einde) opruimen, tenzij --keep.
on_exit() {
  local rc=$?
  if [ "$KEEP" -eq 1 ]; then
    printf '\n'; log "--keep: resources blijven staan"
    echo "   Container:  http://$HOST:$PORT   (naam: $CONTAINER)"
    echo "   Data:       $WORK/data"
    echo "   Opruimen:   $0 --destroy"
  else
    teardown
  fi
  exit $rc
}
trap on_exit EXIT

########## rustic resolven ##########
if command -v rustic >/dev/null 2>&1; then
  RUSTIC="$(command -v rustic)"
else
  log "rustic uit nixpkgs bouwen (eenmalig, gecached)"
  RUSTIC="$(nix build --no-link --print-out-paths nixpkgs#rustic)/bin/rustic"
fi

# Draai een rustic-commando met creds + profiel, als root.
rustic_run() {
  sudo bash -c "cd /etc/rustic && set -a && . /run/agenix/rustic-s3-env && set +a && \
    '$RUSTIC' -P '$PROFILE' --profile-substitute-env $*"
}

########## Voorbereiden ##########
log "Restore-test starten (snapshot: $SNAPSHOT)"
sudo docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
if sudo ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
  fail "Poort $PORT is bezet — draai eerst '$0 --destroy' of maak de poort vrij"; exit 1
fi
sudo rm -rf "$WORK"; sudo mkdir -p "$WORK/data"

########## 1. Restore uit S3 ##########
log "1/4  Terugzetten uit S3"
rustic_run "restore '$SNAPSHOT:/var/lib/vaultwarden' '$WORK/data'" >/dev/null
rustic_run "restore '$SNAPSHOT:/var/backup/db/vaultwarden.sqlite3' '$WORK/data'" >/dev/null
ok "app-state + DB-dump teruggezet"

########## 2. Reassemble ##########
log "2/4  Reassemble: DB-dump wordt db.sqlite3"
sudo mv -f "$WORK/data/vaultwarden.sqlite3" "$WORK/data/db.sqlite3"
sudo sqlite3 "$WORK/data/db.sqlite3" "PRAGMA quick_check;" | grep -qx ok \
  && ok "quick_check: ok" || { fail "DB-check faalde"; exit 1; }

########## 3. Wegwerp-container ##########
log "3/4  Wegwerp-Vaultwarden starten op $HOST:$PORT"
sudo docker run -d --name "$CONTAINER" \
  -e ROCKET_ADDRESS=0.0.0.0 -e ROCKET_PORT=8080 \
  -e SIGNUPS_ALLOWED=false -e TZ=Europe/Amsterdam \
  -v "$WORK/data:/data" \
  -p "$HOST:$PORT:8080" \
  "$IMAGE" >/dev/null
# Wachten tot /alive antwoordt (max ~30s)
for _ in $(seq 1 30); do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://$HOST:$PORT/alive" || true)"
  [ "$code" = "200" ] && break
  sleep 1
done
[ "${code:-}" = "200" ] && ok "/alive -> HTTP 200 (Vaultwarden draait)" \
  || { fail "Container antwoordt niet op /alive"; sudo docker logs "$CONTAINER" 2>&1 | tail -15; exit 1; }

########## 4. Sqlite-tellingen ##########
log "4/4  Inhoud van de gerestorede DB"
USERS="$(sudo sqlite3 "$WORK/data/db.sqlite3" 'SELECT count(*) FROM users;')"
CIPHERS="$(sudo sqlite3 "$WORK/data/db.sqlite3" 'SELECT count(*) FROM ciphers;')"
ok "users=$USERS  ciphers=$CIPHERS"

########## rbw-crypto-test (optioneel) ##########
if [ "$DO_RBW" -eq 1 ]; then
  log "rbw-crypto-test (geïsoleerd) — master-password + TOTP vereist"
  command -v rbw >/dev/null || { fail "rbw niet gevonden"; exit 1; }
  export_rbw_env
  mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR"
  chmod 700 "$XDG_RUNTIME_DIR"

  # E-mail read-only uit de ECHTE rbw-config halen (die zelf niet wijzigen).
  EMAIL="$(jq -r '.email' "$HOME/.config/rbw/config.json")"
  ok "test-account: $EMAIL (uit je echte rbw-config, ongewijzigd)"

  rbw config set base_url "http://$HOST:$PORT"
  rbw config set email "$EMAIL"
  rbw config set pinentry "$PINENTRY"

  log "rbw login (voer je master-password en TOTP-code in)"
  rbw login
  rbw sync
  COUNT="$(rbw list | grep -c . || true)"
  if [ "${COUNT:-0}" -gt 0 ]; then
    ok "rbw ontsleutelde $COUNT items uit de gerestorede vault ✓"
  else
    fail "rbw login lukte maar de lijst is leeg — controleer handmatig"; exit 1
  fi
fi

printf '\n'
log "RESULTAAT: restore-test geslaagd ✓  (users=$USERS, ciphers=$CIPHERS$( [ "$DO_RBW" -eq 1 ] && echo ", rbw=$COUNT ontsleuteld" ))"
