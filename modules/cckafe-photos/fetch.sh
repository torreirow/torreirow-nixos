#!/usr/bin/env bash
# Haalt de foto's van de meet-ups op uit Immich en schrijft ze, samen met een
# manifest, naar de fotomap van de website. Zie docs/cckafe-photos.md en
# modules/cckafe-photos/default.nix.
#
# Per meet-up (uit $MEETUPS_FILES, TSV: slug<TAB>albumnaam) wordt het album op
# naam gezocht, de assets opgehaald en voor elke asset de preview gedownload.
# Immich levert die als WebP op een korte zijde van 800 (modules/immich.nix),
# dus meestal wordt het bestand ongewijzigd overgenomen. De bestanden en het manifest gaan naar een tijdelijke map en
# worden daarna samen naar de fotomap verplaatst, zodat een onderbroken run
# geen half manifest oplevert.
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
# De galerij zet de foto's in een grid van maximaal 1200px breed. Sinds Immich
# `preview` als WebP op korte zijde 800 levert, is dit alleen nog een vangnet:
# het grijpt in bij een niet-WebP-preview (oude cache, of Immich viel terug op
# het origineel) en bij panorama's die breder zijn dan 1200.
MAX_W="${MAX_W:-1200}"
QUALITY="${QUALITY:-82}"

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

  # De assets en hun metadata ophalen en per asset de preview downloaden.
  python3 -c '
import json, sys
d = json.loads(sys.argv[1])
for a in d.get("assets", {}).get("items", []):
    if a.get("type") != "IMAGE":
        continue
    print("\t".join([a["id"], a.get("originalFileName") or "foto",
                      str(a.get("width") or 0), str(a.get("height") or 0)]))
' "$assets_json" > "$TMPROOT/assets.tsv" || true

  manifest_items=()
  idx=0
  while IFS=$'\t' read -r asset_id filename width height; do
    [ -n "$asset_id" ] || continue
    idx=$((idx + 1))
    # Eerst onder een neutrale naam opslaan: het formaat blijkt uit de bytes, en
    # de extensie van het origineel zegt daar niets over (Immich geeft WebP terug
    # voor een bron die .jpg heet).
    raw="$outdir/$(printf '%03d' "$idx").download"
    if ! curl "${CURL_OPTS[@]}" -H "@$AUTH_HEADER" \
        -o "$raw" \
        "$IMMICH_URL/api/assets/$asset_id/thumbnail?size=preview"; then
      log "preview van $filename ophalen mislukt; sla dit bestand over"
      rm -f "$raw"
      continue
    fi
    # Het formaat uit de bestands-signatuur halen, zodat het bestand de extensie
    # krijgt die bij de inhoud hoort en nginx het juiste Content-Type serveert.
    fmt="$(python3 -c '
import sys
head = open(sys.argv[1], "rb").read(12)
if head[:2] == b"\xff\xd8":
    print("jpg")
elif head[:8] == b"\x89PNG\r\n\x1a\n":
    print("png")
elif head[:4] == b"RIFF" and head[8:12] == b"WEBP":
    print("webp")
elif head[:6] in (b"GIF87a", b"GIF89a"):
    print("gif")
else:
    sys.exit(1)
' "$raw" 2>/dev/null || true)"
    if [ -z "$fmt" ]; then
      log "$filename: preview is geen geldige afbeelding; sla over"
      rm -f "$raw"
      continue
    fi
    fname="$(printf '%03d' "$idx").$fmt"

    # Is de preview al WebP en niet breder dan $MAX_W, dan is hercoderen alleen
    # kwaliteitsverlies en CPU: verplaatsen volstaat. Anders doet magick het werk.
    pix_w=0
    if [ "$fmt" = webp ]; then
      pix_w="$(magick identify -format '%w' "$raw" 2>/dev/null || echo 0)"
    fi
    if [ "$fmt" = webp ] && [ "${pix_w:-0}" -gt 0 ] 2>/dev/null \
        && [ "${pix_w:-0}" -le "$MAX_W" ] 2>/dev/null; then
      mv "$raw" "$outdir/$fname"
    else
      outwebp="${fname%.*}.webp"
      if magick "$raw" -auto-orient -resize "${MAX_W}x>" \
          -strip -quality "$QUALITY" "$outdir/$outwebp" 2>/dev/null; then
        rm -f "$raw"
        fname="$outwebp"
      else
        log "omzetten van $filename mislukt; preview blijft staan als $fname"
        mv "$raw" "$outdir/$fname"
      fi
    fi
    dims="$(magick identify -format '%w %h' "$outdir/$fname" 2>/dev/null || echo "${width:-0} ${height:-0}")"
    mw="${dims% *}"; mh="${dims#* }"
    manifest_items+=("$(printf '{"file":"%s","width":%s,"height":%s,"source":"%s"}' \
      "$fname" "${mw:-0}" "${mh:-0}" "$filename")")
  done < "$TMPROOT/assets.tsv"

  if [ "${#manifest_items[@]}" -eq 0 ]; then
    log "geen bruikbare foto's in '$album_name'; $slug blijft zonder galerij"
    rm -rf "${outdir:?}"
    continue
  fi

  # Het manifest: de metadata die de Hugo-layout nodig heeft.
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
