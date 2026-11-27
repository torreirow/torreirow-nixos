# Test van fetch.sh tegen een nep-Immich (python http.server):
#
#   nix build .#checks.x86_64-linux.cckafe-photos -L
{ runCommand, callPackage, python3, curl, jq }:

let
  fetch = callPackage ./package.nix { };
  stub = ./stub_server.py;
in
runCommand "cckafe-photos-test" { nativeBuildInputs = [ fetch python3 curl jq ]; } ''
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

  # 1. Album met twee fotos -> manifest met asset-ids, geen fotobestanden
  reset_calls
  printf 'ass\t%s\n' "meetup-assen-20270201" > "$MEETUPS_FILES"
  cat > "$STUB/album.json" <<'JSON'
  [{"id":"alb-1","albumName":"meetup-assen-20270201","assetCount":2}]
  JSON
  cat > "$STUB/assets.json" <<'JSON'
  {"assets":{"total":2,"items":[
    {"id":"a1","type":"IMAGE","originalFileName":"een.jpg","width":2400,"height":1600,"updatedAt":"2026-11-20T18:47:26.900Z"},
    {"id":"a2","type":"IMAGE","originalFileName":"twee.png","width":1400,"height":2100,"updatedAt":"2026-11-21T09:00:00.000Z"}]}}
  JSON
  cckafe-photos
  check "album gevonden" "$(test -f "$PHOTOS_DIR/ass/manifest.json" && echo yes || echo no)" yes
  check "manifest albumnaam" "$(jq -r '.album' "$PHOTOS_DIR/ass/manifest.json")" "meetup-assen-20270201"
  check "manifest aantal" "$(jq -r '.photos | length' "$PHOTOS_DIR/ass/manifest.json")" "2"
  check "manifest asset-id" "$(jq -r '.photos[0].id' "$PHOTOS_DIR/ass/manifest.json")" "a1"
  check "wijzigingstijd" "$(jq -r '.photos[0].v' "$PHOTOS_DIR/ass/manifest.json")" "2026-11-20T18:47:26.900Z"
  # Immich's preview is `fit: outside` op 800: de korte zijde wordt 800.
  check "liggend: breedte" "$(jq -r '.photos[0].width' "$PHOTOS_DIR/ass/manifest.json")" "1200"
  check "liggend: hoogte" "$(jq -r '.photos[0].height' "$PHOTOS_DIR/ass/manifest.json")" "800"
  check "staand: breedte" "$(jq -r '.photos[1].width' "$PHOTOS_DIR/ass/manifest.json")" "800"
  check "staand: hoogte" "$(jq -r '.photos[1].height' "$PHOTOS_DIR/ass/manifest.json")" "1200"
  check "alleen een manifest" "$(ls "$PHOTOS_DIR/ass")" "manifest.json"
  check "geen preview gedownload" "$(grep -c '/thumbnail' "$STUB/calls" || true)" "0"

  # 2. Album bestaat niet -> het vorige manifest blijft staan
  reset_calls
  printf 'ass\t%s\n' "meetup-bestaat-niet" > "$MEETUPS_FILES"
  cckafe-photos
  check "ontbrekend album: manifest intact" "$(jq -r '.photos | length' "$PHOTOS_DIR/ass/manifest.json")" "2"

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

  # 4. Opnieuw ophalen ruimt oude fotobestanden op (de overstap van kopieen naar proxy)
  reset_calls
  printf 'ass\t%s\n' "meetup-assen-20270201" > "$MEETUPS_FILES"
  cat > "$STUB/album.json" <<'JSON'
  [{"id":"alb-1","albumName":"meetup-assen-20270201","assetCount":2}]
  JSON
  cat > "$STUB/assets.json" <<'JSON'
  {"assets":{"total":2,"items":[
    {"id":"a1","type":"IMAGE","originalFileName":"een.jpg","width":2400,"height":1600,"updatedAt":"2026-11-20T18:47:26.900Z"},
    {"id":"a2","type":"IMAGE","originalFileName":"twee.png","width":1400,"height":2100,"updatedAt":"2026-11-21T09:00:00.000Z"}]}}
  JSON
  printf 'nep' > "$PHOTOS_DIR/ass/001.webp"
  cckafe-photos
  check "oude fotobestanden weg" "$(ls "$PHOTOS_DIR/ass")" "manifest.json"

  # 5. Onbereikbare Immich -> de dienst faalt, het vorige manifest blijft staan
  export IMMICH_URL=http://127.0.0.1:19999
  if cckafe-photos 2>/dev/null; then echo "FOUT: verwacht falen bij onbereikbare Immich"; exit 1; fi
  check "Immich down: manifest intact" "$(jq -r '.photos | length' "$PHOTOS_DIR/ass/manifest.json")" "2"
  export IMMICH_URL=http://127.0.0.1:18734

  # 6. Geen meet-up-lijst: geen fout, niets doen (verse installatie)
  rm -f "$MEETUPS_FILES"
  reset_calls
  if ! cckafe-photos; then echo "FOUT: ontbrekende lijst mag geen fout zijn"; exit 1; fi
  check "geen lijst: niets opgehaald" "$(calls)" 0

  # 7. Twee lijsten, door ":" gescheiden, worden samengevoegd (systemd splitst
  #    Environment= op spaties, dus een spatie-lijst komt niet aan)
  mkdir -p "$PWD/l1" "$PWD/l2"
  printf 'ass\t%s\n' "meetup-assen-20270201" > "$PWD/l1/index.txt"
  printf 'leeg\t%s\n' "meetup-leeg" > "$PWD/l2/index.txt"
  cat > "$STUB/assets.json" <<'JSON'
  {"assets":{"total":1,"items":[
    {"id":"a1","type":"IMAGE","originalFileName":"een.jpg","width":1200,"height":800,"updatedAt":"2026-11-20T18:47:26.900Z"}]}}
  JSON
  rm -rf "$PHOTOS_DIR/ass"
  reset_calls
  MEETUPS_FILES="$PWD/l1/index.txt:$PWD/l2/index.txt" cckafe-photos
  check "twee lijsten: ass opgehaald" "$(test -f "$PHOTOS_DIR/ass/manifest.json" && echo yes || echo no)" yes
  check "twee lijsten: beide albums bekeken" "$(grep -c 'GET /api/albums' "$STUB/calls")" 1

  # 8. De sleutel gaat via een header-bestand, niet in de proceslijst
  grep -q 'x-api-key: %s' ${./fetch.sh}
  if grep -qE 'api_key=|&api_key|\?key=' ${./fetch.sh}; then
    echo "FOUT: sleutel mag niet als URL-parameter"; exit 1
  fi

  # 9. Geen share-link: het script gebruikt nergens slug/key als album-parameter
  if grep -qE 'shared-links' ${./fetch.sh}; then
    echo "FOUT: script mag geen share-link gebruiken"; exit 1
  fi

  echo "alle tests geslaagd" > $out
''
