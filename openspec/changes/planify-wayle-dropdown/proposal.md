## Why

De wayle bar heeft geen integratie met Planify. Om snel zicht te houden op
open taken uit een specifiek project (bijv. TN-ToDo) moet je nu de volledige
app openen. Een dropdown in de bar — zoals bluetooth en weather — geeft
directe inzage zonder van context te wisselen.

## What Changes

- Nieuw wayle dropdown-component `planify` dat taken uit de Planify SQLite
  database laadt en toont in een GTK popover
- Badge in de bar toont het totaal aantal open taken in het geconfigureerde project
- Taken worden gegroepeerd: **Verlopen** (rood) / **Vandaag + geen deadline** / **Komend**
- Taken zonder deadline worden behandeld alsof ze vandaag zijn (getoond in de "Vandaag" sectie)
- Knop in dropdown-header opent Planify direct
- Configureerbaar project per naam (default: `Inbox`) en DB-pad (default: XDG standaard)
- `rusqlite` toegevoegd als dependency aan `wayle-shell`
- `[modules.planify]` config-sectie toegevoegd aan `wayle-config`

## Capabilities

### New Capabilities

- `planify-dropdown`: GTK dropdown in wayle bar met Planify taken, gegroepeerd
  op urgentie, configureerbaar project en DB-pad

### Modified Capabilities

_(geen)_

## Impact

- **wayle fork** (`/home/wtoorren/data/git/torreirow/wayle`):
  - `crates/wayle-config`: nieuw config schema voor `[modules.planify]`
  - `crates/wayle-shell`: nieuw dropdown-module + rusqlite dependency
- **NixOS config** (`home/hyprland/wayle.nix`):
  - `[modules.planify]` sectie in `config.toml`
  - `planify` in bar layout
- Geen breaking changes, geen externe services vereist
