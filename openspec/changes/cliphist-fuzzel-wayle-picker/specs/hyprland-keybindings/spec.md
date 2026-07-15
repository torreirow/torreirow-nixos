## ADDED Requirements

### Requirement: Ctrl+Super+C keybinding voor clipboard picker
Het systeem SHALL `Ctrl+Super+C` binden aan de cliphist fuzzel picker.

#### Scenario: Keybinding activeert picker
- **WHEN** gebruiker `Ctrl+Super+C` indrukt in Hyprland
- **THEN** wordt `cliphist list | fuzzel --dmenu | cliphist decode | wl-copy` uitgevoerd

#### Scenario: Bestaande clipboard keybinding ongewijzigd
- **WHEN** gebruiker `Ctrl+Super+V` indrukt
- **THEN** opent clipse TUI in alacritty zoals voorheen
