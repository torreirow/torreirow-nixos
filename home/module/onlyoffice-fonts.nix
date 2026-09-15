# OnlyOffice DesktopEditors ziet geen fonts uit fonts.packages.
#
# Anders dan LibreOffice gebruikt OnlyOffice geen fontconfig, maar een in de
# binary hardcoded lijst paden. Uit die lijst bestaat op NixOS alleen ~/.fonts:
#
#   /usr/share/fonts            -- bestaat niet op NixOS
#   /usr/local/share/fonts      -- bestaat niet op NixOS
#   /usr/share/X11/fonts/TTF    -- bestaat niet op NixOS
#   ~/.fonts                    -- wordt wel gescand, ook recursief
#
# Let op: ~/.local/share/fonts staat NIET in die lijst (dat leek zo door de
# string /usr/local/share/fonts in de binary, maar is het niet).
#
# Empirisch vastgesteld met een testopstelling van een echte kopie naast een
# symlink in ~/.fonts: OnlyOffice pakt alleen het echte bestand op en slaat de
# symlink over. home.file valt daarmee af -- dat symlinkt altijd -- vandaar een
# activation-script dat de fonts echt kopieert.
#
# Zonder deze module scant OnlyOffice uitsluitend zijn eigen bundled fontmap in
# de nix-store (21 bestanden) en blijven alle systeemfonts onzichtbaar, niet
# alleen deze.
#
# Bewust alleen de EGH-fonts en niet de hele systeem-fontmap: dat zijn er hier
# ~23.800 (google-fonts + de volledige nerd-fonts-set), die OnlyOffice bij elke
# cache-rebuild stuk voor stuk parset en van thumbnails voorziet.
{ pkgs, lib, ... }:

let
  eghFonts = pkgs.callPackage ../../pkgs/egh-fonts { };
in
{
  home.activation.eghFontsForOnlyoffice = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    target="$HOME/.fonts/egh"
    stamp="''${XDG_STATE_HOME:-$HOME/.local/state}/home-manager/egh-fonts-store-path"

    # Alleen werk doen als de fonts daadwerkelijk veranderd zijn: het wissen van
    # de OnlyOffice-cache hieronder kost anders bij elke switch een rebuild.
    if [ "$(cat "$stamp" 2>/dev/null)" != "${eghFonts}" ]; then
      run rm -rf $VERBOSE_ARG "$target"
      run mkdir -p $VERBOSE_ARG "$target"
      run cp --no-preserve=mode,ownership -t "$target" \
        ${eghFonts}/share/fonts/opentype/*.otf \
        ${eghFonts}/share/fonts/truetype/*.ttf
      run chmod 0644 "$target"/*.otf "$target"/*.ttf

      # Via run sh -c, anders zou de redirect de stamp ook bij een dry-run
      # schrijven en slaat de echte switch daarna het kopieren over.
      run mkdir -p $VERBOSE_ARG "$(dirname "$stamp")"
      run sh -c "printf '%s\\n' '${eghFonts}' > '$stamp'"

      # OnlyOffice cachet de fontlijst; zonder wissen leest hij de oude terug.
      run rm -f $VERBOSE_ARG \
        "$HOME/.local/share/onlyoffice/desktopeditors/data/fonts/AllFonts.js" \
        "$HOME/.local/share/onlyoffice/desktopeditors/data/fonts/font_selection.bin" \
        "$HOME/.local/share/onlyoffice/desktopeditors/data/fonts/fonts.log"
    fi
  '';
}
