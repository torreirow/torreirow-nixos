## 1. X11 DPI fix

- [x] 1.1 Voeg `xresources.properties."Xft.dpi" = 120` toe aan `home/hyprland/envs.nix`

## 2. Font scale script

- [x] 2.1 Definieer `font-scale` shell script in `home/hyprland/bindings.nix` met acties `up`, `down`, `reset` via `gsettings` en `awk` (stap 0.1, min 0.8, max 2.0)
- [x] 2.2 Voeg `notify-send` toe aan het script voor visuele feedback

## 3. Keybindings

- [x] 3.1 Voeg `SUPER CTRL SHIFT, equal` binding toe (font-scale up)
- [x] 3.2 Voeg `SUPER CTRL SHIFT, minus` binding toe (font-scale down)
- [x] 3.3 Voeg `SUPER CTRL SHIFT, 0` binding toe (font-scale reset)
- [x] 3.4 Voeg de drie keybindings toe aan het shortcuts-popup overzicht in `bindings.nix`
