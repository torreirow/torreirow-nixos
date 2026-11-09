## Why

De `Ctrl+Super+C` fuzzel clipboard picker werkt keyboard-driven maar biedt geen visuele integratie met de wayle-bar. Een native clipboard dropdown — klikbaar via een icoon in de bar — sluit aan bij de bestaande dropdown-stijl van planify, notificaties en media en maakt clipboard history muis-toegankelijk zonder extra venster.

## What Changes

- Nieuw GTK4/Relm4 dropdown component `clipboard` in de wayle fork (`crates/wayle-shell/src/shell/bar/dropdowns/clipboard/`)
- Registratie van `"clipboard"` als dropdown factory in `dropdowns/mod.rs`
- Refresh van clipboard entries op het `map` signal van de popover (niet via polling)
- Klik op entry → `cliphist decode | wl-copy` en sluit de dropdown
- Nieuw custom module in `home/hyprland/wayle.nix` met clipboard icoon en `left-click = "dropdown:clipboard"`
- Clipboard icoon toegevoegd aan bar layout naast planify

## Capabilities

### New Capabilities

- `clipboard-dropdown-component`: GTK4/Relm4 Rust component dat cliphist history toont als klikbare dropdown in de wayle-bar
- `wayle-bar-clipboard-module`: Configuratie van het clipboard icoon en module in wayle.nix

### Modified Capabilities

## Impact

- **wayle fork** (`/home/wtoorren/data/git/torreirow/wayle`):
  - `crates/wayle-shell/src/shell/bar/dropdowns/clipboard/` — nieuw (4 bestanden)
  - `crates/wayle-shell/src/shell/bar/dropdowns/mod.rs` — registratie
  - `overlays/wayle.nix` — versie bump na wijziging in fork
- **torreirow-nixos**:
  - `home/hyprland/wayle.nix` — custom module + bar layout
- Geen nieuwe NixOS dependencies; `cliphist` al aanwezig als home package
