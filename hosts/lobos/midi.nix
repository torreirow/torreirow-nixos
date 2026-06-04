{ config, pkgs, lib, ... }:

let
  salamander-sf2 = pkgs.stdenv.mkDerivation {
    pname = "salamander-grand-piano";
    version = "3+20200602";
    src = pkgs.fetchurl {
      url = "http://freepats.zenvoid.org/Piano/SalamanderGrandPiano/SalamanderGrandPiano-SF2-V3+20200602.tar.xz";
      sha256 = "04z2a3b3f3rjwqszj0y7ih28h2g4ij7vlbgp6a1xaq5ssxhv1v8m";
    };
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/share/sounds/sf2
      cp SalamanderGrandPiano-V3+20200602.sf2 $out/share/sounds/sf2/SalamanderGrandPiano.sf2
    '';
  };

  piano-script = pkgs.writeShellScriptBin "piano" ''
    # Zet KT USB Audio (dockingstation) op analoog stereo profiel
    KT_DEV=$(${pkgs.wireplumber}/bin/wpctl status 2>/dev/null | grep "KT USB Audio \[alsa\]" | grep -o "[0-9]*\." | head -1 | tr -d '.')
    if [ -n "$KT_DEV" ]; then
      ${pkgs.wireplumber}/bin/wpctl set-profile "$KT_DEV" 1 2>/dev/null
      sleep 0.5
      KT_SINK=$(${pkgs.wireplumber}/bin/wpctl status 2>/dev/null | grep "KT USB Audio Analog Stereo" | grep -o "[0-9]*\." | head -1 | tr -d '.')
      if [ -n "$KT_SINK" ]; then
        ${pkgs.wireplumber}/bin/wpctl set-default "$KT_SINK" 2>/dev/null
        ${pkgs.wireplumber}/bin/wpctl set-volume "$KT_SINK" 0.9 2>/dev/null
      fi
    fi

    # Verbind GX61 met FluidSynth zodra FluidSynth zijn MIDI poort aangemaakt heeft
    connect_midi() {
      for i in $(seq 1 20); do
        sleep 0.5
        if ${pkgs.alsa-utils}/bin/aconnect -l 2>/dev/null | grep -q "Impact GX61"; then
          FS_PORT=$(${pkgs.alsa-utils}/bin/aconnect -l 2>/dev/null | grep "FLUID Synth" | head -1 | grep -o "^client [0-9]*" | grep -o "[0-9]*")
          if [ -n "$FS_PORT" ]; then
            ${pkgs.alsa-utils}/bin/aconnect "Impact GX61:0" "$FS_PORT:0" 2>/dev/null && break
          fi
        fi
      done
    }
    connect_midi &

    exec env PIPEWIRE_LATENCY=256/48000 ${pkgs.fluidsynth}/bin/fluidsynth \
      -a pulseaudio \
      -m alsa_seq \
      -g 1.0 \
      ${salamander-sf2}/share/sounds/sf2/SalamanderGrandPiano.sf2
  '';
in

{
  # Real-time audio prioriteit voor lage latency
  security.rtkit.enable = true;

  environment.systemPackages = [
    pkgs.fluidsynth
    pkgs.alsa-utils
    salamander-sf2
    piano-script
  ];
}
