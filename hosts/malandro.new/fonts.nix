{ config, lib, pkgs, unstable, ... }:

let
  fontsList = with pkgs; [
    awesome
    dejavu_fonts
    fira-code-nerdfont
    google-fonts
    inconsolata-nerdfont
    inter
    lato
    liberation_ttf
    meslo-lg
    nerdfonts
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
    packages = fontsList;

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
