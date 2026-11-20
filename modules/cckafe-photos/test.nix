# Test van fetch.sh tegen een nep-Immich (python http.server):
#
#   nix build .#checks.x86_64-linux.cckafe-photos -L
{ runCommand, callPackage, python3, curl, jq, imagemagick }:

let
  fetch = callPackage ./package.nix { };
  stub = ./stub_server.py;
in
runCommand "cckafe-photos-test" { nativeBuildInputs = [ fetch python3 curl jq imagemagick ]; } ''
  set -euo pipefail

  export STUB=$PWD/stub
  mkdir -p "$STUB"
  python3 ${stub} 18734 "$STUB" &
  STUB_PID=$!
  trap 'kill $STUB_PID 2>/dev/null || true' EXIT
  for i in $(seq 50); do curl -s localhost:18734/api/albums >/dev/null 2>&1 && break; sleep 0.1; done

  export IMMICH_URL=http://127.0.0.1:18734
  export PHOTOS_DIR=$PWD/photos
  export MEETUPS_FILES=$PWD/meetups.tsv
  export KEY_FILE=$PWD/key
  mkdir -p "$PHOTOS_DIR"
  printf 'testkey' > "$KEY_FILE"

  calls() { cat "$STUB/calls" 2>/dev/null | wc -l | tr -d ' '; }
  reset_calls() { rm -f "$STUB/calls"; }
  check() { echo "--- $1"; [ "$2" = "$3" ] || { echo "FOUT: verwacht '$3', kreeg '$2'"; exit 1; }; }

  # 1. Album met twee fotos -> manifest en bestanden
  reset_calls
  printf 'ass\t%s\n' "meetup-assen-20270201" > "$MEETUPS_FILES"
  cat > "$STUB/album.json" <<'JSON'
  [{"id":"alb-1","albumName":"meetup-assen-20270201","assetCount":2}]
  JSON
  cat > "$STUB/assets.json" <<'JSON'
  {"assets":{"total":2,"items":[
    {"id":"a1","type":"IMAGE","originalFileName":"een.jpg","width":1200,"height":800},
    {"id":"a2","type":"IMAGE","originalFileName":"twee.png","width":900,"height":600}]}}
  JSON
  cckafe-photos
  check "album gevonden" "$(test -f "$PHOTOS_DIR/ass/manifest.json" && echo yes || echo no)" yes
  check "twee fotobestanden" "$(ls "$PHOTOS_DIR/ass" | grep -c -E '^[0-9]{3}\.')" 2
  check "manifest albumnaam" "$(jq -r '.album' "$PHOTOS_DIR/ass/manifest.json")" "meetup-assen-20270201"
  check "manifest fotonaam" "$(jq -r '.photos[0].file' "$PHOTOS_DIR/ass/manifest.json")" "001.webp"
  # De breedte komt uit het verkleinde bestand, niet uit de API-JSON (die zegt
  # 1200x800); de stub levert een 1x1-JPEG, dus het manifest moet 1 zeggen.
  check "manifest breedte" "$(jq -r '.photos[0].width' "$PHOTOS_DIR/ass/manifest.json")" "1"
  check "omgezet naar webp" "$(jq -r '.photos[0].file' "$PHOTOS_DIR/ass/manifest.json" | grep -c '\.webp$')" "1"
  check "manifest aantal" "$(jq -r '.photos | length' "$PHOTOS_DIR/ass/manifest.json")" "2"

  # 1b. Immich levert de preview zelf al als WebP (korte zijde 800). Dan neemt de
  #     dienst het bestand ongewijzigd over: geen hercodering, dus identieke bytes.
  reset_calls
  magick -size 1200x800 gradient:'#2b4a6f-#7fb2d9' -strip -quality 82 "webp:$STUB/preview.bin"
  printf 'image/webp' > "$STUB/preview.type"
  printf 'webp\t%s\n' "meetup-webp" > "$MEETUPS_FILES"
  cat > "$STUB/album.json" <<'JSON'
  [{"id":"alb-3","albumName":"meetup-webp","assetCount":1}]
  JSON
  cat > "$STUB/assets.json" <<'JSON'
  {"assets":{"total":1,"items":[
    {"id":"a3","type":"IMAGE","originalFileName":"drie.jpg","width":2400,"height":1600}]}}
  JSON
  cckafe-photos
  check "webp-preview: extensie uit de bytes" \
    "$(jq -r '.photos[0].file' "$PHOTOS_DIR/webp/manifest.json")" "001.webp"
  check "webp-preview: breedte uit het bestand" \
    "$(jq -r '.photos[0].width' "$PHOTOS_DIR/webp/manifest.json")" "1200"
  check "webp-preview: ongewijzigd overgenomen" \
    "$(cmp -s "$STUB/preview.bin" "$PHOTOS_DIR/webp/001.webp" && echo gelijk || echo anders)" "gelijk"

  # 1c. Een WebP-preview die breder is dan 1200 (panorama) wordt wel verkleind.
  magick -size 2400x800 gradient:'#2b4a6f-#7fb2d9' -strip -quality 82 "webp:$STUB/preview.bin"
  cckafe-photos
  check "panorama: terug naar 1200 breed" \
    "$(jq -r '.photos[0].width' "$PHOTOS_DIR/webp/manifest.json")" "1200"
  rm -f "$STUB/preview.bin" "$STUB/preview.type"

  # 2. Album bestaat niet -> de vorige foto's blijven staan (geen lege galerij)
  reset_calls
  printf 'ass\t%s\n' "meetup-bestaat-niet" > "$MEETUPS_FILES"
  cckafe-photos
  check "ontbrekend album: vorige foto's intact" "$(ls "$PHOTOS_DIR/ass" | grep -c -E '^[0-9]{3}\.')" 2

  # 3. Leeg album -> geen galerij
  reset_calls
  printf 'leeg\t%s\n' "meetup-leeg" > "$MEETUPS_FILES"
  cat > "$STUB/album.json" <<'JSON'
  [{"id":"alb-2","albumName":"meetup-leeg","assetCount":0}]
  JSON
  cat > "$STUB/assets.json" <<'JSON'
  {"assets":{"total":0,"items":[]}}
  JSON
  cckafe-photos
  check "leeg album: geen map" "$(test -e "$PHOTOS_DIR/leeg" && echo exists || echo gone)" gone

  # 4. Onbereikbare Immich -> de diest faalt, vorige foto's blijven staan
  reset_calls
  printf 'ass\t%s\n' "meetup-assen-20270201" > "$MEETUPS_FILES"
  cat > "$STUB/album.json" <<'JSON'
  [{"id":"alb-1","albumName":"meetup-assen-20270201","assetCount":2}]
  JSON
  cckafe-photos
  check "opnieuw ophalen: twee bestanden" "$(ls "$PHOTOS_DIR/ass" | grep -c -E '^[0-9]{3}\.')" 2
  export IMMICH_URL=http://127.0.0.1:19999
  if cckafe-photos 2>/dev/null; then echo "FOUT: verwacht falen bij onbereikbare Immich"; exit 1; fi
  check "Immich down: foto's intact" "$(ls "$PHOTOS_DIR/ass" | grep -c -E '^[0-9]{3}\.')" 2
  export IMMICH_URL=http://127.0.0.1:18734

  # 4b. Geen meet-up-lijst: geen fout, niets doen (verse installatie)
  rm -f "$MEETUPS_FILES"
  reset_calls
  if ! cckafe-photos; then echo "FOUT: ontbrekende lijst mag geen fout zijn"; exit 1; fi
  check "geen lijst: niets opgehaald" "$(calls)" 0

  # 4c. Twee lijsten, door ":" gescheiden, worden samengevoegd (systemd splitst
  #     Environment= op spaties, dus een spatie-lijst komt niet aan)
  mkdir -p "$PWD/l1" "$PWD/l2"
  printf 'ass\t%s\n' "meetup-assen-20270201" > "$PWD/l1/index.txt"
  printf 'leeg\t%s\n' "meetup-leeg" > "$PWD/l2/index.txt"
  cat > "$STUB/assets.json" <<'JSON'
  {"assets":{"total":1,"items":[
    {"id":"a1","type":"IMAGE","originalFileName":"een.jpg","width":1200,"height":800}]}}
  JSON
  rm -rf "$PHOTOS_DIR/ass"
  reset_calls
  MEETUPS_FILES="$PWD/l1/index.txt:$PWD/l2/index.txt" cckafe-photos
  check "twee lijsten: ass opgehaald" "$(test -f "$PHOTOS_DIR/ass/manifest.json" && echo yes || echo no)" yes
  check "twee lijsten: beide albums bekeken" "$(grep -c 'GET /api/albums' "$STUB/calls")" 1

  # 5. De sleutel gaat via een header-bestand, niet in de proceslijst
  grep -q 'x-api-key: %s' ${./fetch.sh}
  if grep -qE 'api_key=|&api_key|\?key=' ${./fetch.sh}; then
    echo "FOUT: sleutel mag niet als URL-parameter"; exit 1
  fi

  # 6. Geen share-link: het script gebruikt nergens slug/key als album-parameter
  if grep -qE 'shared-links' ${./fetch.sh}; then
    echo "FOUT: script mag geen share-link gebruiken"; exit 1
  fi

  echo "alle tests geslaagd" > $out
''
