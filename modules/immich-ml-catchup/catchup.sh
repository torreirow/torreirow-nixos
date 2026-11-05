# Start Immich's "Missing"-jobs voor slim zoeken en gezichten zodra de ML-dienst op lobos
# (weer) bereikbaar is. Zie docs/immich.md en modules/immich-ml-catchup/default.nix.
#
# Staat in $STATE_DIR/state: "down" (ML was onbereikbaar) of "up <epoch>" (laatste start).
# Starten gebeurt als ML net terug is, bij de eerste run, en daarna hooguit elke $MAX_AGE s.

ML_URL="${ML_URL:-http://10.77.0.2:3003}"
IMMICH_URL="${IMMICH_URL:-http://127.0.0.1:2283}"
STATE_DIR="${STATE_DIR:-/var/lib/immich-ml-catchup}"
KEY_FILE="${KEY_FILE:-${CREDENTIALS_DIRECTORY:-/nonexistent}/api-key}"
MAX_AGE="${MAX_AGE:-21600}"
QUEUES=(smartSearch faceDetection)

state="$STATE_DIR/state"
now=$(date +%s)

if [ "$(curl -fsS --max-time 5 "$ML_URL/ping" 2>/dev/null)" != "pong" ]; then
  echo down > "$state"
  echo "ML onbereikbaar ($ML_URL); niets gestart"
  exit 0
fi

prev=$(cat "$state" 2>/dev/null || true)
last=0
case "$prev" in "up "*) last="${prev#up }" ;; esac
if [ -n "$prev" ] && [ "$prev" != down ] && [ $((now - last)) -lt "$MAX_AGE" ]; then
  echo "ML bereikbaar; jobs $(( (now - last) / 60 )) min geleden gestart, niets te doen"
  exit 0
fi

key=$(cat "$KEY_FILE")
for q in "${QUEUES[@]}"; do
  # Sleutel via een header-bestand, zodat hij niet in de proceslijst staat.
  body=$(curl -sS --max-time 30 -w '\n%{http_code}' -X PUT "$IMMICH_URL/api/jobs/$q" \
    -H @<(printf 'x-api-key: %s\n' "$key") \
    -H 'Content-Type: application/json' \
    -d '{"command":"start","force":false}')
  code="${body##*$'\n'}"
  if [ "$code" = 200 ]; then
    echo "$q: Missing gestart"
  elif [ "$code" = 400 ] && grep -q "already running" <<<"$body"; then
    echo "$q: draait al"
  else
    echo "$q: HTTP $code: ${body%$'\n'*}" >&2
    exit 1
  fi
done
echo "up $now" > "$state"
