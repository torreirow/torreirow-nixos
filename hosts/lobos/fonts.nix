{ config, lib, pkgs, unstable, ... }:

let
  fontsList = with pkgs; [
    awesome
    dejavu_fonts
#    fira-code-nerdfont
    google-fonts
#    inconsolata-nerdfont
    inter
    lato
    liberation_ttf
    meslo-lg
    noto-fonts
    noto-fonts-color-emoji
    open-sans
    rubik
    ubuntu_font_family
  ];

  # 👇 custom fonts (bijv. in je home directory of repository)
  customFonts = pkgs.stdenv.mkDerivation {
    pname = "custom-fonts";
    version = "1.0";
    src = ../../fonts;  # of bijvoorbeeld ./fonts als je ze in je nixos-config repo zet
    installPhase = ''
      mkdir -p $out/share/fonts
      cp -r $src/* $out/share/fonts/
    '';
  };
in
{
  fonts = {
    enableDefaultPackages = true;
    fontconfig.enable = true;
    packages =
      fontsList
      ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts)
      ++ [ customFonts ];

    fontconfig = {
      defaultFonts = {
        serif = [ "Liberation Serif" ];
        sansSerif = [ "Ubuntu" "Vazirmatn" ];
        monospace = [ "Ubuntu Mono" ];
      };
    };
  };

  environment.systemPackages = fontsList;
}

