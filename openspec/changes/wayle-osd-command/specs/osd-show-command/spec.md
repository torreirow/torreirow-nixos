## ADDED Requirements

### Requirement: CLI commando wayle osd show
Het systeem SHALL een `wayle osd show` subcommand bieden met verplichte parameters `--label` en `--icon`, en optionele parameters `--value` en `--fraction`.

#### Scenario: Slider OSD tonen
- **WHEN** `wayle osd show --label "Tekstgrootte" --icon "format-text-larger-symbolic" --value "1.1×" --fraction 0.15` wordt aangeroepen
- **THEN** toont de OSD overlay een slider met label, icon, value-tekst en progress bar op 15%

#### Scenario: Label-only OSD tonen
- **WHEN** `wayle osd show --label "Caps Lock" --icon "input-keyboard-symbolic"` wordt aangeroepen zonder `--fraction`
- **THEN** toont de OSD overlay een toggle-stijl weergave met label en icon, zonder progress bar

#### Scenario: Wayle shell niet actief
- **WHEN** `wayle osd show` wordt aangeroepen maar de wayle shell draait niet
- **THEN** geeft het commando een foutmelding terug en eindigt met exit code 1

### Requirement: OSD volgt bestaande dismiss-timing
Het systeem SHALL de custom OSD automatisch verbergen na dezelfde duur als de geconfigureerde OSD dismiss-tijd.

#### Scenario: Auto-dismiss
- **WHEN** een OSD getoond wordt via `wayle osd show`
- **THEN** verdwijnt de OSD na de geconfigureerde `[osd] duration`

### Requirement: font-scale script gebruikt wayle osd show
Het systeem SHALL de `notify-send` aanroep in het font-scale script vervangen door `wayle osd show`.

#### Scenario: Font scale omhoog
- **WHEN** gebruiker `Super+Ctrl+Shift+=` indrukt
- **THEN** toont de wayle OSD (niet een notificatie-popup) de nieuwe schaalfactor als slider
