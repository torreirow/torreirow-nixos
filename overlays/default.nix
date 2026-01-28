final: prev: 


{
  inherit (import ./rbw.nix final prev) rbw;

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
#    inherit (import ./solidtime.nix) solidtime-desktop;

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


}

