{ pkgs ? import <nixpkgs> {} }:

nixpkgs.mkDerivation {
  name = "toggl-cli";

  src = ./;

  sha256 = "1cw6fha61ar5bcyqfmkvcl1q3zmic16hlq382k50w31gpbyw8v8p";

  buildInputs = [ pkgs.python39 ];

  installPhase = ''
    mkdir -p $out/bin;
    cp -r $src/bin/* $out/bin;
  '';
}

