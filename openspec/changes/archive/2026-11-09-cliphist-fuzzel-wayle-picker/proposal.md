## Why

De huidige clipboard setup gebruikt clipse als TUI (terminal UI) wat niet aansluit bij de visuele stijl van wayle-bar. Een fuzzel-gebaseerde picker gestyled met de wayle Tokyo Night palette biedt een consistente, moderne clipboard experience zonder extra venster of terminal.

## What Changes

- Voeg `cliphist` toe als clipboard history daemon (vervangt clipse als history backend)
- Voeg `fuzzel` toe met wayle-stijl config (Tokyo Night palette, Inter font, rounded corners)
- Nieuwe keybinding `Ctrl+Super+C` opent cliphist via fuzzel picker
- `clipse` TUI blijft behouden via bestaande `Ctrl+Super+V` keybinding
- `wl-clip-persist` blijft actief voor clipboard persistentie

## Capabilities

### New Capabilities

- `cliphist-fuzzel-picker`: Clipboard history picker via fuzzel dropdown gestyled met wayle palette

### Modified Capabilities

- `hyprland-keybindings`: Nieuwe `Ctrl+Super+C` keybinding toegevoegd voor clipboard picker

## Impact

- `home/hyprland/default.nix`: cliphist daemon toevoegen aan `exec-once`
- `home/hyprland/bindings.nix`: Nieuwe keybinding `Ctrl+Super+C`
- `home/hyprland/fuzzel.nix`: Nieuw bestand met fuzzel home-manager config
- `home/hyprland/default.nix`: Import van fuzzel.nix
- Nieuwe packages: `cliphist`, `fuzzel`
- Bestaande clipse setup blijft ongewijzigd
