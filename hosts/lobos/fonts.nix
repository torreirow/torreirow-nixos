{ config, lib, pkgs, unstable, ... }:

let
  # Lokaal aangeleverde EGH-fonts (Letter Gothic Std, Blenda Script).
  # Niet in nixpkgs beschikbaar, dus als eigen derivation uit hosts/lobos/fonts/egh/.
  eghFonts = pkgs.runCommandLocal "egh-fonts" { } ''
    install -Dm444 -t "$out/share/fonts/opentype" ${./fonts/egh}/*.otf
    install -Dm444 -t "$out/share/fonts/truetype" ${./fonts/egh}/*.ttf
  '';

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
