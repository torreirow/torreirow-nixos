{ config, lib, pkgs, unstable, ... }:

let
  # Lokaal aangeleverde EGH-fonts (Letter Gothic Std, Blenda Script).
  # Gedeeld met home/module/onlyoffice-fonts.nix -- zie pkgs/egh-fonts/default.nix.
  eghFonts = pkgs.callPackage ../../pkgs/egh-fonts { };

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
    ubuntu-classic
  ];
in
{
  fonts = {
    enableDefaultPackages = true;
    fontconfig.enable = true;
    packages = fontsList ++ [ eghFonts ] ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts) ;

    fontconfig = {
      defaultFonts = {
        serif = [  "Liberation Serif"  ];
        sansSerif = [ "Ubuntu" "Vazirmatn" ];
        monospace = [ "Ubuntu Mono" ];
      };
    };
  };
  environment.systemPackages = fontsList;
}
