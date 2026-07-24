## ADDED Requirements

### Requirement: Clipboard history picker via fuzzel
Het systeem SHALL een clipboard history picker bieden via fuzzel, gestyled met de wayle Tokyo Night palette.

#### Scenario: Picker openen via keybinding
- **WHEN** gebruiker `Ctrl+Super+C` indrukt
- **THEN** opent fuzzel met de volledige clipboard history in wayle stijl

#### Scenario: Item selecteren en plakken
- **WHEN** gebruiker een item selecteert in de fuzzel picker
- **THEN** wordt het item in het clipboard geplaatst zodat het geplakt kan worden

#### Scenario: Stijl matcht wayle palette
- **WHEN** de fuzzel picker zichtbaar is
- **THEN** gebruikt hij kleuren bg=#16161e, fg=#c0caf5, selection=#292e42, match/border=#7aa2f7, font Inter

### Requirement: cliphist daemon actief bij opstarten
Het systeem SHALL cliphist als daemon starten bij het opstarten van Hyprland.

#### Scenario: Daemon start automatisch
- **WHEN** Hyprland opstart
- **THEN** draait `cliphist store` als watcher via `wl-paste --watch`

#### Scenario: Geen conflict met clipse
- **WHEN** zowel cliphist als clipse actief zijn
- **THEN** draaien beide zonder conflict naast elkaar
