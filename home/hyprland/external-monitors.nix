# Bekende externe schermen, herkend aan hun EDID-beschrijving (niet aan de poort). Gebruikt door de
# Hyprland-config (default.nix) en het schermstand-menu (bindings.nix), zodat een stand uit het menu
# de eigen resolutie/schaal van het scherm niet overschrijft. Onbekende schermen: preferred, schaal 1.
[
  {
    # Nikkei 4K-TV. Generieke EDID van de leverancier ("CTV"), dus een andere TV met hetzelfde board
    # matcht ook. Vereist TV-instelling EDID 2.0 op die HDMI-ingang: met EDID 1.4 biedt hij 4K maar
    # tot 30 Hz (en 1080p als preferred, wat met TV-stand "Ongeschaald" klein is en met de andere
    # standen overscan geeft, waardoor de wayle-bar wegvalt). Met EDID 2.0: 4K@60 preferred.
    desc = "CTV CTV 0x00000001";
    mode = "3840x2160@60";
    scale = 2;
  }
]
