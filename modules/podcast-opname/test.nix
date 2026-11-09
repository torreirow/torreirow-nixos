# Test van podrec.sh met een nep-pw-record/-pw-dump/-notify-send:
#
#   nix build .#checks.x86_64-linux.podrec -L
{ runCommand, callPackage, writeShellScriptBin, writeScriptBin, symlinkJoin, python3, sox }:

let
  # pw-dump: de nodes uit $STUB_NODES (één naam per regel) als pw-dump-JSON.
  # pw-record: schrijft tot SIGINT, maakt dan een echte stereo-FLAC (links 440 Hz, rechts stil);
  # faalt als $STUB_FAIL bestaat.
  stubPipewire = symlinkJoin {
    name = "stub-pipewire";
    paths = [
      (writeShellScriptBin "pw-dump" ''
        printf '['
        sep=
        while read -r n; do printf '%s{"info":{"props":{"node.name":"%s"}}}' "$sep" "$n"; sep=,; done < "$STUB_NODES"
        printf ']'
      '')
      # Python i.p.v. bash: een achtergrondproces van podrec erft een genegeerde SIGINT, en bash
      # kan die niet meer opvangen. De echte pw-record (C) zet zijn eigen handler, net als dit.
      (writeScriptBin "pw-record" ''
        #!${python3}/bin/python3
        import os, signal, subprocess, sys, time
        if os.path.exists(os.environ["STUB_FAIL"]):
            sys.exit("nep-fout")
        out = sys.argv[-1]
        with open(os.environ["STUB_CALLS"], "a") as f:
            f.write(" ".join(sys.argv[1:]) + "\n")
        open(out, "w").write("bezig\n")
        def stop(*_):
            subprocess.run(["${sox}/bin/sox", "-n", "-r", "48000", "-b", "24", "-c", "2", out,
                            "synth", "2", "sine", "440", "remix", "1", "0"], check=True)
            sys.exit(0)
        signal.signal(signal.SIGINT, stop)
        while True:
            time.sleep(0.1)
      '')
    ];
  };
  stubNotify = writeShellScriptBin "notify-send" ''echo "''${@: -1}" >> "$NOTIFY_LOG"'';
  podrec = callPackage ./package.nix { pipewire = stubPipewire; libnotify = stubNotify; };
in
runCommand "podrec-test" { nativeBuildInputs = [ podrec sox ]; } ''
  set -euo pipefail
  export HOME=$PWD/home XDG_RUNTIME_DIR=$PWD/run STUB_NODES=$PWD/nodes STUB_CALLS=$PWD/calls
  export STUB_FAIL=$PWD/fail NOTIFY_LOG=$PWD/notify
  mkdir -p $HOME $XDG_RUNTIME_DIR
  check() { echo "--- $1"; [ "$2" = "$3" ] || { echo "FOUT: verwacht '$3', kreeg '$2'"; exit 1; }; }

  # 1. Mic 2 ontbreekt: geen opname, melding noemt mic 2
  printf 'podcast-mic-1\nandere-node\n' > $STUB_NODES
  if podrec start; then echo "FOUT: start zonder mic 2 slaagde"; exit 1; fi
  grep -q 'Podcast mic 2 niet gevonden' $NOTIFY_LOG
  check "geen opname zonder mic 2" "$(ls $HOME/Podcast 2>/dev/null | wc -l)" 0

  # 1b. Beide mics, maar de stereobron ontbreekt (PipeWire nog niet herstart)
  printf 'podcast-mic-1\npodcast-mic-2\n' > $STUB_NODES
  if podrec start; then echo "FOUT: start zonder podcast-2mics slaagde"; exit 1; fi
  grep -q 'Podcast (2 mics) ontbreekt' $NOTIFY_LOG
  check "geen opname zonder stereobron" "$(ls $HOME/Podcast 2>/dev/null | wc -l)" 0

  # 2. Alles aanwezig: één opname van de stereobron, één map
  printf 'podcast-mic-1\npodcast-mic-2\npodcast-2mics\n' > $STUB_NODES
  podrec start
  check "één map" "$(ls $HOME/Podcast | wc -l)" 1
  dir=$HOME/Podcast/$(ls $HOME/Podcast)
  grep -q -- '--target podcast-2mics --channels 2 .*\.opname\.flac' $STUB_CALLS
  podrec status | grep -q 'opname loopt'

  # 3. Tweede start weigert
  if podrec start; then echo "FOUT: tweede start slaagde"; exit 1; fi
  grep -q 'Er loopt al een opname' $NOTIFY_LOG
  check "nog steeds één map" "$(ls $HOME/Podcast | wc -l)" 1
  check "één opnemer" "$(wc -l < $STUB_CALLS)" 1

  # 4. Stop: gesplitst in twee mono-sporen, links = mic 1, rechts = mic 2; tussenbestanden weg
  podrec stop
  check "mic1 mono" "$(soxi -c $dir/mic1.flac)" 1
  check "mic2 mono" "$(soxi -c $dir/mic2.flac)" 1
  check "even lang" "$(soxi -s $dir/mic1.flac)" "$(soxi -s $dir/mic2.flac)"
  check "mic1 heeft geluid" "$(sox $dir/mic1.flac -n stat 2>&1 | awk '/Maximum amplitude/ {print ($3 > 0.5)}')" 1
  check "mic2 is stil" "$(sox $dir/mic2.flac -n stat 2>&1 | awk '/Maximum amplitude/ {print $3}')" 0.000000
  check "geen tussenbestanden" "$(ls -A $dir | tr '\n' ' ')" "mic1.flac mic2.flac "
  grep -q "Opname opgeslagen in $dir" $NOTIFY_LOG
  podrec status | grep -q 'geen opname'

  # 5. Stop zonder opname
  podrec stop | grep -q 'Er loopt geen opname'

  # 6. Opnemer faalt meteen: melding, geen hangende state
  touch $STUB_FAIL
  if podrec start; then echo "FOUT: start met falende opnemer slaagde"; exit 1; fi
  grep -q 'Opname kon niet starten' $NOTIFY_LOG
  podrec status | grep -q 'geen opname'

  touch $out
''
