{ pkgs, ... }:

let
  version = "0.1.1";
  src = pkgs.fetchurl {
    url = "https://github.com/whyisdifficult/jiratui/archive/refs/tags/v${version}.tar.gz";
    sha256 = "sha256-i1TGOgLDCAxEfYcYuABHwTzQhPwcpWfW2I2sOBq/qAA="; # vervang als prefetch een andere hash geeft
  };

  # Maak een python omgeving met de benodigde packages ingebakken
  pythonEnv = pkgs.python311.withPackages (ps: with ps; [ requests pyyaml rich ]);

  jiratui = pkgs.stdenv.mkDerivation {
    pname = "jiratui";
    inherit version src;

    nativeBuildInputs = [ pkgs.makeWrapper ];

    # buildInputs is niet nodig omdat we de python interpreter uit pythonEnv gebruiken
    installPhase = ''
      mkdir -p $out/bin
      # kopieer repo inhoud naar $out
      cp -r * $out/
      # zorg dat het script uitvoerbaar is (naam in repo: jiratui.py)
      chmod +x $out/jiratui.py || true
      # wrapper gebruikt de python interpreter uit pythonEnv (met deps)
      makeWrapper ${pythonEnv}/bin/python $out/bin/jiratui \
        --add-flags "$out/jiratui.py"
    '';
    meta = with pkgs.lib; {
      description = "Wrapper for jiratui (from GitHub)";
      license = licenses.mit;
    };
  };
in
{
  environment.systemPackages = [
    jiratui
  ];
}
