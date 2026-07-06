## Why

XWayland apps verschijnen kleiner dan Wayland apps doordat de monitor scale (1.25) niet doorgegeven wordt aan X11. Daarnaast ontbreekt een snelle manier om de tekstgrootte tijdelijk te verhogen — bijvoorbeeld bij presentaties of wanneer de ogen wat meer rust nodig hebben.

## What Changes

- `xresources.properties."Xft.dpi"` instellen op 120 (96 × 1.25) zodat X11/XWayland apps dezelfde tekstgrootte hebben als Wayland apps
- Shell script `font-scale` met drie acties: `up`, `down`, `reset` via `gsettings text-scaling-factor`
- Drie Hyprland keybindings: `Super+Ctrl+Shift+=` (groter), `Super+Ctrl+Shift+-` (kleiner), `Super+Ctrl+Shift+0` (reset)
- `notify-send` feedback na elke aanpassing (verschijnt via wayle notificatie popup)

## Capabilities

### New Capabilities

- `font-scaling`: Interactieve font scale control via keybindings met visuele feedback

### Modified Capabilities

## Impact

- `home/hyprland/envs.nix` — `xresources.properties` toevoegen
- `home/hyprland/bindings.nix` — drie keybindings + script definitie toevoegen
- Geen nieuwe dependencies; `gsettings` en `notify-send` zijn al beschikbaar
