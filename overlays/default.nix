final: prev: 


{

  quarto = prev.quarto.override {
    extraRPackages = [
      prev.rPackages.reticulate
    ];
    extraPythonPackages = ps: with ps; [
      plotly
      numpy
      pandas
      matplotlib
      tabulate
    ];
  };

    # importeer Solidtime overlay
    inherit (import ./solidtime.nix) solidtime-desktop;

#    opsgenie-sdk = prev.python311Packages.buildPythonPackage rec {
#      pname = "opsgenie-sdk";
#      version = "2.1.5";
#
#      src = prev.fetchPypi {
#        inherit pname version;
#        hash = "sha256-w4ovDHrLy+uSAs7YDshXte2i2ZkZOS/tQIO9+nvjJmk=";
#      };
#
#  # Voeg de benodigde build dependencies toe
#  nativeBuildInputs = [ prev.python311Packages.setuptools prev.python311Packages.wheel prev.python311Packages.pip ];
#
#  propagatedBuildInputs = with prev.python311Packages; [
#    requests
#    tenacity
#    python-dateutil
#    prettytable
#  ];
#
#  meta = with prev.lib; {
#    description = "Opsgenie SDK for Python";
#    license = licenses.mit;
#    homepage = "https://github.com/opsgenie/opsgenie-python-sdk";
#    maintainers = with maintainers; [ ];
#  };
#};

cooklang = prev.appimageTools.wrapType2 {
  name = "Cooklang";
  version = "0.2.5";
  src = prev.fetchurl {
    url = "https://downloads.cook.md/cook-desktop-v0.2.5/cook-desktop_0.2.5_linux_x86_64.AppImage";
    sha256 = "sha256-UTlTC2QptXUo3TEAcvgIT455XGvCcdR9d4z0lagxKb4=";
  };

  extraInstallCommands = ''
    mkdir -p $out/share/applications
    echo "[Desktop Entry]
    Version=1.0
    Name=Cooklang
    Comment=Recipe management application
    Exec=$out/bin/cooklang
    Icon=cooklang
    Terminal=false
    Type=Application
    Categories=Utility;" > $out/share/applications/cooklang.desktop
  '';

  meta = with prev.lib; {
    homepage = "https://cooklang.org/";
    description = "Recipe management application";
    platforms = platforms.linux;
  };
};

#bambu-studio = prev.bambu-studio.overrideAttrs (oldAttrs: {
#    version = "01.00.01.50";
#    src = prev.fetchFromGitHub {
#      owner = "bambulab";
#      repo = "BambuStudio";
#      rev = "v01.00.01.50";
#      hash = "sha256-7mkrPl2CQSfc1lRjl1ilwxdYcK5iRU//QGKmdCicK30=";
#    };
#    patches = [];
#  }
#);

bambu-studio = prev.appimageTools.wrapType2 {
  pname = "bambu-studio";
  version = "v02.04.00.70";

  src = prev.fetchurl {
    url = "https://github.com/bambulab/BambuStudio/releases/download/v02.04.00.70/Bambu_Studio_ubuntu-22.04_PR-8834.AppImage";
    sha256 = "sha256-/xcVD3YPuAr8mNmEGxNMC62kiX1qrzaAi1F6S+0sEbA=";
  };

  extraPkgs = pkgs: with pkgs; [
    zlib
    glib
    gtk3
    libglvnd
    mesa
    libxkbcommon
    xorg.libX11
    xorg.libXext
    xorg.libXi
    xorg.libXtst
    xorg.libXrender
  ];
};


}

