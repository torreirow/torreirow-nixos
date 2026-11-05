# Test van catchup.sh tegen een nep-ML/-Immich (python http.server):
#
#   nix build .#checks.x86_64-linux.immich-ml-catchup -L
{ runCommand, callPackage, python3, curl }:

let
  catchup = callPackage ./package.nix { };
  stub = ./stub_server.py;
in
runCommand "immich-ml-catchup-test" { nativeBuildInputs = [ catchup python3 curl ]; } ''
  set -euo pipefail
  export STUB=$PWD/stub; mkdir -p $STUB
  python3 ${stub} 18733 $STUB &
  for i in $(seq 50); do curl -s localhost:18733/health >/dev/null && break; sleep 0.1; done

  export ML_URL=http://127.0.0.1:18733 IMMICH_URL=http://127.0.0.1:18733
  export STATE_DIR=$PWD/state KEY_FILE=$PWD/key MAX_AGE=21600
  mkdir -p $STATE_DIR; printf 'testkey' > $KEY_FILE
  calls() { cat $STUB/calls 2>/dev/null | wc -l; }
  check() { echo "--- $1"; [ "$2" = "$3" ] || { echo "FOUT: verwacht $3, kreeg $2"; exit 1; }; }

  # 1. ML onbereikbaar: niets gestart, state down
  touch $STUB/ml-down
  immich-ml-catchup
  check "ML down: geen calls" "$(calls)" 0
  check "ML down: state" "$(cat $STATE_DIR/state)" down

  # 2. ML terug: beide queues gestart met de sleutel
  rm $STUB/ml-down
  immich-ml-catchup
  check "ML terug: twee calls" "$(calls)" 2
  check "ML terug: queues" "$(cut -d' ' -f1 $STUB/calls | tr '\n' ' ')" "smartSearch faceDetection "
  check "ML terug: sleutel" "$(cut -d' ' -f2 $STUB/calls | sort -u)" testkey
  check "ML terug: force=false" "$(cut -d' ' -f3 $STUB/calls | sort -u)" false
  grep -q '^up ' $STATE_DIR/state

  # 3. Direct nog een run: binnen MAX_AGE, niets nieuws
  immich-ml-catchup
  check "binnen MAX_AGE: geen nieuwe calls" "$(calls)" 2

  # 4. MAX_AGE verstreken: opnieuw starten; queue draait al (400) telt als gelukt
  echo "up 0" > $STATE_DIR/state
  touch $STUB/already-running
  immich-ml-catchup
  check "na MAX_AGE: opnieuw" "$(calls)" 4
  rm $STUB/already-running

  # 5. Verkeerde sleutel: dienst faalt (exit != 0), state blijft oud
  echo down > $STATE_DIR/state
  printf 'fout' > $KEY_FILE
  if immich-ml-catchup; then echo "FOUT: verwacht falen bij 401"; exit 1; fi
  check "401: state ongewijzigd" "$(cat $STATE_DIR/state)" down

  # 6. Sleutel niet in de proceslijst (alleen via header-bestand)
  grep -q -- '-H @<(' ${./catchup.sh}

  echo "alle tests geslaagd" > $out
''
