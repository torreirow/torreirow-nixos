{ config, pkgs, lib, ... }:

let
  salamander-sf2 = pkgs.stdenv.mkDerivation {
    pname = "salamander-grand-piano";
    version = "3+20200602";
    src = pkgs.fetchurl {
      url = "http://freepats.zenvoid.org/Piano/SalamanderGrandPiano/SalamanderGrandPiano-SF2-V3+20200602.tar.xz";
      sha256 = "0908gvb8rh8lqjhxqsym7d1pp1a6makd3k3paas8dgy7fg24gysy";
    };
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/share/sounds/sf2
      cp SalamanderGrandPiano-V3+20200602.sf2 $out/share/sounds/sf2/SalamanderGrandPiano.sf2
    '';
  };

  piano-script = pkgs.writeShellScriptBin "piano" ''
    exec env PIPEWIRE_LATENCY=256/48000 ${pkgs.fluidsynth}/bin/fluidsynth \
      -a jack \
      -m alsa_seq \
      -g 1.0 \
      ${salamander-sf2}/share/sounds/sf2/SalamanderGrandPiano.sf2
  '';
in

{
  # Real-time audio prioriteit voor lage latency
  security.rtkit.enable = true;

  # PipeWire JACK bridge voor lage latency audio
  services.pipewire.jack.enable = true;

  environment.systemPackages = [
    pkgs.fluidsynth
    salamander-sf2
    piano-script
  ];
}
