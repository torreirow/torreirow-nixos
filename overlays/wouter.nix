final: prev: {
  inherit (import ./rbw.nix final prev) rbw;

  quarto = prev.quarto.override {
    extraRPackages = [ prev.rPackages.reticulate ];
    extraPythonPackages = ps: with ps; [
      plotly numpy pandas matplotlib tabulate
    ];
  };

  # Cooklang (correct)
  cooklang = prev.appimageTools.wrapType2 {
    name = "Cooklang";
    version = "0.2.5";
    src = prev.fetchurl {
      url = "https://downloads.cook.md/cook-desktop-v0.2.5/cook-desktop_0.2.5_linux_x86_64.AppImage";
      sha256 = "sha256-UTlTC2QptXUo3TEAcvgIT455XGvCcdR9d4z0lagxKb4=";
    };
    extraInstallCommands = ''
      mkdir -p $out/share/applications
      cat > $out/share/applications/cooklang.desktop <<EOF
      [Desktop Entry]
      Version=1.0
      Name=Cooklang
      Comment=Recipe management application
      Exec=$out/bin/cooklang
      Icon=cooklang
      Terminal=false
      Type=Application
      Categories=Utility;
      EOF
    '';
    meta = with prev.lib; {
      homepage = "https://cooklang.org/";
      description = "Recipe management application";
      platforms = platforms.linux;
    };
  };


}

