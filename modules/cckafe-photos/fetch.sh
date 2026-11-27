#!/usr/bin/env bash
# Haalt de foto's van de meet-ups op uit Immich en schrijft per album een
# manifest naar de fotomap van de website. Zie docs/cckafe-photos.md en
# modules/cckafe-photos/default.nix.
#
# Per meet-up (uit $MEETUPS_FILES, TSV: slug<TAB>albumnaam) wordt het album op
# naam gezocht en worden de assets opgehaald. Er wordt niets gedownload: het
# manifest verwijst met de asset-id naar Immich, waar nginx de preview ophaalt
# (/immich/<id>.webp, zie modules/cckafe.nix). Het manifest gaat naar een
# tijdelijke map en wordt daarna naar de fotomap verplaatst, zodat een
# onderbroken run geen half manifest oplevert.
#
# De API-sleutel komt uit $CREDENTIALS_DIRECTORY/api-key en gaat via een
# header-bestand, zodat hij niet in de proceslijst staat. Er wordt GEEN
# share-link gebruikt of aangemaakt: de albums blijven privé.
set -euo pipefail

IMMICH_URL="${IMMICH_URL:-http://127.0.0.1:2283}"
PHOTOS_DIR="${PHOTOS_DIR:-/var/lib/cckafe-photos}"
# Beide sites: productie en test. Een test-release (./release.sh test) schrijft de
# lijst alleen in de test-webroot, en de foto's zijn voor beide hetzelfde. De
# bestaande bestanden worden samengevoegd; een ontbrekend bestand is geen fout.
# Door ":" gescheiden: systemd splitst Environment= op spaties, dus een lijst met
# spaties komt niet aan.
MEETUPS_FILES="${MEETUPS_FILES:-/var/www/cckafe.com/meetups/index.txt:/var/www/test.cckafe.com/meetups/index.txt}"
KEY_FILE="${KEY_FILE:-${CREDENTIALS_DIRECTORY:-/nonexistent}/api-key}"
CURL_OPTS=(--silent --show-error --fail --max-time 60 --max-time 30)
# De korte zijde van Immich's `preview`, uit modules/immich.nix (`image.preview.size`).
# Het manifest rekent de afmetingen daarmee uit; er wordt niets gedownload of gemeten.
PREVIEW_SIZE="${PREVIEW_SIZE:-800}"

log() { echo "cckafe-photos: $*"; }
fail() { echo "cckafe-photos: $*" >&2; exit 1; }

[ -r "$KEY_FILE" ] || fail "geen API-sleutel op $KEY_FILE"

KEY="$(cat "$KEY_FILE")"
# Header-bestand: de sleutel staat zo niet in de proceslijst.
AUTH_HEADER="$(mktemp)"
TMPROOT="$(mktemp -d)"
cleanup() { rm -f "$AUTH_HEADER"; rm -rf "$TMPROOT"; }
trap cleanup EXIT
printf 'x-api-key: %s\n' "$KEY" > "$AUTH_HEADER"

# De lijst(en) samenvoegen tot één werklijst. Ontbreekt alles, dan is er nog niets
# om op te halen: geen fout, gewoon niets doen (verse installatie of nog geen
# release gedaan). Anders zou de timer blijven falen.
merged="$TMPROOT/meetups.tsv"
: > "$merged"
while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -r "$f" ] || continue
  cat "$f" >> "$merged"
done < <(printf '%s\n' "$MEETUPS_FILES" | tr ':' '\n')
if [ ! -s "$merged" ]; then
  log "geen meet-up-lijst gevonden ($MEETUPS_FILES); niets te doen (draai eerst ./release.sh)"
  exit 0
fi
sort -u "$merged" -o "$merged"

api() {
  # api <pad> [json-body] -> antwoord op stdout
  local path="$1" body="${2:-}"
  if [ -n "$body" ]; then
    curl "${CURL_OPTS[@]}" -X POST -H "@$AUTH_HEADER" \
      -H "Content-Type: application/json" -d "$body" "$IMMICH_URL$path"
  else
    curl "${CURL_OPTS[@]}" -H "@$AUTH_HEADER" "$IMMICH_URL$path"
  fi
}

# 1. Alle albums van het account ophalen (eenmalig).
ALBUMS_JSON="$(api /api/albums)" || fail "Immich niet bereikbaar op $IMMICH_URL"

# 2. Per meet-up: album op naam zoeken, assets ophalen, previews downloaden.
updated=0
while IFS=$'\t' read -r slug album_name; do
  [ -n "${slug:-}" ] || continue
  case "$slug" in \#*) continue ;; esac

  # Het album op naam zoeken.
  album_id="$(python3 -c '
import json, sys
albums = json.loads(sys.argv[1])
want = sys.argv[2]
for a in albums:
    if a.get("albumName") == want:
        print(a["id"])
        break
' "$ALBUMS_JSON" "$album_name" 2>/dev/null || true)"

  if [ -z "$album_id" ]; then
    log "album '$album_name' niet gevonden; $slug blijft zonder foto's"
    rm -rf "${TMPROOT:?}/$slug"
    continue
  fi

  assets_json="$(api /api/search/metadata "{\"albumIds\":[\"$album_id\"]}")" \
    || { log "assets van '$album_name' ophalen mislukt; sla over"; continue; }

  count="$(python3 -c '
import json, sys
d = json.loads(sys.argv[1])
print(d.get("assets", {}).get("total", 0))
' "$assets_json" 2>/dev/null || echo 0)"

  if [ "${count:-0}" -eq 0 ]; then
    log "album '$album_name' is leeg; $slug blijft zonder foto's"
    rm -rf "${TMPROOT:?}/$slug"
    continue
  fi

  outdir="$TMPROOT/$slug"
  mkdir -p "$outdir"

  # De assets ophalen als regels met id, afmetingen van de preview, wijzigingstijd
  # en de oorspronkelijke bestandsnaam. Niets downloaden: de browser haalt de foto
  # via nginx bij Immich, op de asset-id.
  python3 - "$assets_json" "$PREVIEW_SIZE" > "$TMPROOT/photos.jsonl" <<'PY' || true
import json, sys

assets_json, preview_size = sys.argv[1], int(sys.argv[2])
for a in json.loads(assets_json).get("assets", {}).get("items", []):
    if a.get("type") != "IMAGE":
        continue
    w = int(a.get("width") or 0)
    h = int(a.get("height") or 0)
    if w > 0 and h > 0:
        # Immich's preview is `fit: outside` op een vierkant van preview_size: de
        # KORTE zijde wordt preview_size en de lange loopt door. Nooit vergroten.
        scale = min(1.0, preview_size / min(w, h))
        pw = int(round(w * scale))
        ph = int(round(h * scale))
    else:
        pw = ph = 0
    print(json.dumps({
        "id": a["id"],
        "width": pw,
        "height": ph,
        "v": a.get("updatedAt") or "",
        "source": a.get("originalFileName") or "foto",
    }, ensure_ascii=False))
PY

  manifest_items=()
  while IFS= read -r item; do
    [ -n "$item" ] || continue
    manifest_items+=("$item")
  done < "$TMPROOT/photos.jsonl"

  if [ "${#manifest_items[@]}" -eq 0 ]; then
    log "geen bruikbare foto's in '$album_name'; $slug blijft zonder galerij"
    rm -rf "${outdir:?}"
    continue
  fi

  # Het manifest: de index die app.js nodig heeft om de galerij te bouwen.
  {
    printf '{'
    printf '"slug":"%s","album":"%s","photos":[' "$slug" "$album_name"
    local_i=0
    for item in "${manifest_items[@]}"; do
      if [ "$local_i" -gt 0 ]; then printf ','; fi
      printf '%s' "$item"
      local_i=$((local_i + 1))
    done
    printf ']}\n'
  } > "$outdir/manifest.json"

  log "$slug: ${#manifest_items[@]} foto(s) uit '$album_name'"
  updated=$((updated + 1))
done < "$merged"

# 3. De bijgewerkte mappen atomair naar de fotomap verplaatsen. De vorige
#    inhoud blijft staan als de run faalt.
mkdir -p "$PHOTOS_DIR"
for dir in "$TMPROOT"/*/; do
  [ -d "$dir" ] || continue
  slug="$(basename "$dir")"
  target="$PHOTOS_DIR/$slug"
  rm -rf "${target}.new"
  mv "$dir" "${target}.new"
  rm -rf "$target.old"
  if [ -d "$target" ]; then mv "$target" "$target.old"; fi
  mv "${target}.new" "$target"
  rm -rf "$target.old"
done

log "klaar: $updated meet-up(s) bijgewerkt"
