{ lib, pkgs, ... }:

let
  patchScript = pkgs.writeShellScript "subtitleedit-patch-shortcuts.sh" ''
    settings="$HOME/.config/Subtitle Edit/Settings.xml"

    if [ ! -f "$settings" ]; then
      echo "SubtitleEdit settings niet gevonden, sla over"
      echo "Start SubtitleEdit eenmalig zodat de settings aangemaakt worden, daarna opnieuw home-manager switch"
      exit 0
    fi

    ${pkgs.xmlstarlet}/bin/xmlstarlet ed -L \
      -u "//Shortcuts/WaveformVerticalZoom"    -v "Control+Shift+Up"    \
      -u "//Shortcuts/WaveformVerticalZoomOut" -v "Control+Shift+Down"  \
      -u "//Shortcuts/WaveformZoomIn"          -v "Control+Shift+Right" \
      -u "//Shortcuts/WaveformZoomOut"         -v "Control+Shift+Left"  \
      "$settings"

    echo "SubtitleEdit waveform shortcuts gepatcht"
  '';
in {
  home.activation.subtitleEditShortcuts = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD ${patchScript}
  '';
}
