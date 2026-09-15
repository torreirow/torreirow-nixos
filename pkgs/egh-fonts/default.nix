# EGH-fonts (Letter Gothic Std, Blenda Script).
#
# Niet in nixpkgs beschikbaar, daarom als eigen derivation uit de .otf/.ttf
# hiernaast. Wordt door twee kanten gebruikt:
#
#   - hosts/lobos/fonts.nix        -> fonts.packages, voor alles wat fontconfig
#                                     gebruikt (LibreOffice, GTK/Qt-apps, ...)
#   - home/module/onlyoffice-fonts.nix -> ~/.local/share/fonts, want OnlyOffice
#                                     gebruikt geen fontconfig
{ runCommandLocal }:

runCommandLocal "egh-fonts" { } ''
  install -Dm444 -t "$out/share/fonts/opentype" ${./.}/*.otf
  install -Dm444 -t "$out/share/fonts/truetype" ${./.}/*.ttf
''
