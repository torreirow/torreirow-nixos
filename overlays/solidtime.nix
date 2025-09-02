self: super: {
  solidtime-desktop = super.stdenv.mkDerivation rec {
    pname = "solidtime-desktop";
    version = "0.0.40";

    src = super.fetchurl {
      url = "https://github.com/solidtime-io/solidtime-desktop/releases/download/v${version}/solidtime-x64.tar.gz";
      sha256 = "sha256-0gywlm0cwlqrpr943fybv2wksk9jvp1kl2047sxdm5l3iqmqzp9p";
    };

    nativeBuildInputs = [ super.autoPatchelfHook ];
    buildInputs = [ super.stdenv.cc.cc.lib ];

    unpackPhase = "true"; # we pakken zelf uit in installPhase

    installPhase = ''
      mkdir -p $out/opt/solidtime
      tar -xzf $src -C $out/opt/solidtime
      mkdir -p $out/bin
      ln -s $out/opt/solidtime/solidtime-desktop $out/bin/solidtime-desktop
    '';

    meta = with super.lib; {
      description = "Solidtime Desktop client for time tracking";
      homepage = "https://github.com/solidtime-io/solidtime-desktop";
      license = licenses.agpl3Plus;
      platforms = [ "x86_64-linux" ];
    };
  };
}

