## Why

De huidige solidtime integratie in wayle bestaat uit een `[[modules.custom]]` shell script dat `solidtime-waybar` aanroept — een apart pakket dat de Solidtime API direct benadert. Dit werkt niet meer betrouwbaar en biedt geen interactie (start/stop timers). De `soltty` CLI (eigen project) is volledig functioneel maar wordt nog niet benut als interactieve bar module.

## What Changes

- **Nieuw**: Native `solidtime` bar module in de wayle fork die live de lopende timer toont (`⏱ HH:MM:SS`) via `soltty current --json` polling
- **Nieuw**: Native `solidtime` dropdown (GTK4 Popover, zelfde patroon als `weather`/`planify`) met volledig interactieve tijdtracker UI: status card, description entry, project picker, start/stop knop, recent entries
- **Nieuw**: `SolidtimeConfig` in `wayle-config` als officieel config schema (`[modules.solidtime]` in `wayle.toml`)
- **Nieuw**: `Solidtime` variant in `BarModule` enum — plaatsbaar als `"solidtime"` in de bar layout
- **Verwijderd**: `[[modules.custom]]` solidtime sectie uit `home/hyprland/wayle.nix`
- **Verwijderd**: `solidtime-waybar-input` flake input uit de wayle home module

## Capabilities

### New Capabilities

- `solidtime-bar-module`: Native wayle bar module die de Solidtime timer status live weergeeft en de solidtime dropdown opent bij klikken
- `solidtime-dropdown`: Interactieve GTK4 dropdown voor het starten/stoppen van Solidtime timers, inclusief project selectie en recente entries

### Modified Capabilities

## Impact

- **wayle fork** (`/home/wtoorren/data/git/torreirow/wayle`): nieuwe Rust crates code in `wayle-config`, `wayle-shell`, `wayle-styling`
- **torreirow-nixos** (`home/hyprland/wayle.nix`): custom solidtime module verwijderd, `solidtime-waybar-input` dependency weg
- **Afhankelijkheid**: `soltty` binary moet beschikbaar zijn op `$PATH` (al aanwezig via flake)
- **Config**: gebruikers kunnen `[modules.solidtime]` toevoegen aan `wayle.toml` en `"solidtime"` in de bar layout plaatsen
