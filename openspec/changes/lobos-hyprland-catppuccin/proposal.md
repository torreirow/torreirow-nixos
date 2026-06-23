## Why

De huidige setup op lobos draait GNOME 49 als enige desktop environment. Er is behoefte aan een Hyprland tiling window manager sessie als alternatief — met een cleane visuele stijl via Catppuccin Mocha — zonder de GNOME setup te verliezen. Het moet mogelijk zijn om bij elke login te kiezen tussen GNOME en Hyprland zonder rebuild.

## What Changes

- Nieuwe NixOS module `hosts/lobos/hyprland.nix` met `programs.hyprland.enable` en alle benodigde systeem-level packages
- Nieuwe home-manager module `home/hyprland/default.nix` met declaratieve Hyprland config via `wayland.windowManager.hyprland`
- Catppuccin Mocha als kleurschema voor Hyprland borders, waybar en rofi
- Waybar als statusbalk (top bar met workspaces, clock, systeem info)
- Rofi-wayland als app launcher (Super+D)
- Hyprpaper voor wallpaper beheer
- Hyprlock voor schermvergrendeling
- Hypridle voor automatische lock na inactiviteit
- Mako voor notificaties
- Kitty als standaard terminal binnen Hyprland sessie
- GNOME setup blijft volledig intact — GDM toont beide sessies

## Non-goals

- Geen HyDe/Hyprdots of andere imperatieve dotfiles frameworks
- Geen volledige vervanging van GNOME
- Geen home-manager integratie voor andere hosts dan lobos

## Capabilities

### New Capabilities

- `hyprland-session`: Werkende Hyprland Wayland sessie op lobos, selecteerbaar via GDM naast de bestaande GNOME sessie
- `hyprland-catppuccin-theme`: Catppuccin Mocha kleurschema toegepast op Hyprland decoraties, waybar en rofi

### Modified Capabilities

- `lobos-desktop`: lobos ondersteunt nu twee DE sessies (GNOME + Hyprland)

## Impact

- **hosts/lobos/hyprland.nix**: nieuw bestand — systeem-level Hyprland config
- **hosts/lobos/configuration.nix**: import van hyprland.nix toevoegen
- **home/hyprland/default.nix**: nieuw bestand — home-manager Hyprland + tools config
- **flake.nix**: home-manager module voor wtoorren@linuxdesktop uitbreiden met hyprland module
- **Packages toegevoegd**: hyprland, waybar, rofi-wayland, hyprpaper, hyprlock, hypridle, mako, kitty, catppuccin-hyprland, catppuccin-gtk, catppuccin-cursors
- **Geen breaking changes** voor bestaande GNOME setup (gnome-wayland.nix blijft ongewijzigd)
