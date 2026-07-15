## 1. Packages en fuzzel config

- [x] 1.1 Maak `home/hyprland/fuzzel.nix` aan met fuzzel home-manager config (wayle Tokyo Night palette, Inter font, border-radius)
- [x] 1.2 Voeg `cliphist` en `fuzzel` toe als packages in de home config

## 2. Hyprland startup

- [x] 2.1 Voeg cliphist store watcher toe aan `exec-once` in `home/hyprland/default.nix`: `wl-paste --watch cliphist store`
- [x] 2.2 Importeer `fuzzel.nix` in `home/hyprland/default.nix`

## 3. Keybinding

- [x] 3.1 Voeg `Ctrl+Super+C` keybinding toe aan `home/hyprland/bindings.nix` voor `cliphist list | fuzzel --dmenu | cliphist decode | wl-copy`
- [x] 3.2 Voeg comment toe aan de keybinding legenda in bindings.nix

## 4. Verificatie

- [x] 4.1 Voer `home-manager switch` uit en test `Ctrl+Super+C` opent fuzzel clipboard picker
- [x] 4.2 Controleer dat `Ctrl+Super+V` (clipse TUI) nog steeds werkt
