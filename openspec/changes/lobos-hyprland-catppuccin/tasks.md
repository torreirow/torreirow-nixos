## 1. NixOS module: hosts/lobos/hyprland.nix

- [x] 1.1 Maak `hosts/lobos/hyprland.nix` aan met `programs.hyprland.enable = true` en `programs.hyprland.xwayland.enable = true`
- [x] 1.2 Voeg `xdg-desktop-portal-hyprland` toe aan `xdg.portal.extraPortals`
- [x] 1.3 Voeg alle Hyprland ecosystem packages toe aan `environment.systemPackages` (hyprpaper, hyprlock, hypridle, waybar, rofi-wayland, mako, kitty, catppuccin-hyprland, catppuccin-gtk, catppuccin-cursors, grimblast)

## 2. Integratie in lobos configuratie

- [x] 2.1 Voeg `./hyprland.nix` toe aan de imports in `hosts/lobos/configuration.nix`

## 3. Home-manager module: home/hyprland/default.nix

- [x] 3.1 Maak `home/hyprland/default.nix` aan met `wayland.windowManager.hyprland.enable = true`
- [x] 3.2 Voeg basis keybindings toe (SUPER+Return=kitty, SUPER+D=rofi, SUPER+Q=killactive, SUPER+L=hyprlock, SUPER+1-9=workspace, SUPER+SHIFT+1-9=movetoworkspace, SUPER+H/J/K/L=focus, SUPER+F=fullscreen, Print=grimblast screenshot)
- [x] 3.3 Voeg Catppuccin Mocha border kleuren toe (active: mauve `cba6f7`, inactive: surface2 `585b70`)
- [x] 3.4 Voeg `exec-once` autostart toe voor hyprpaper, waybar, hypridle en mako

## 4. Waybar config: home/hyprland/waybar.nix

- [x] 4.1 Maak `home/hyprland/waybar.nix` aan met `programs.waybar.enable = true`
- [x] 4.2 Configureer top bar met modules: workspaces links, window title midden, volume + battery + clock rechts
- [x] 4.3 Voeg Catppuccin Mocha CSS styling toe

## 5. Hyprlock config: home/hyprland/hyprlock.nix

- [x] 5.1 Maak `home/hyprland/hyprlock.nix` aan met `programs.hyprlock.enable = true` en Catppuccin Mocha kleuren

## 6. Hypridle config: home/hyprland/hypridle.nix

- [x] 6.1 Maak `home/hyprland/hypridle.nix` aan met `services.hypridle.enable = true`
- [x] 6.2 Configureer timeouts: 300s → dim scherm, 600s → hyprlock, suspend → hyprlock

## 7. Home-manager registratie in flake.nix

- [x] 7.1 Voeg `./home/hyprland/default.nix` toe aan de modules lijst van `homeConfigurations."wtoorren@linuxdesktop"` in `flake.nix`

## 8. Bouwen en testen

- [x] 8.1 Voer `sudo nixos-rebuild switch --flake .#lobos` uit en controleer op fouten
- [x] 8.2 Voer `home-manager switch --flake .#wtoorren@linuxdesktop` uit en controleer op fouten
- [ ] 8.3 Controleer of Hyprland sessie verschijnt in GDM naast GNOME sessie
- [ ] 8.4 Start Hyprland sessie en test basis keybindings (terminal, launcher, venster sluiten, lock)

## 9. Monitor configuratie testen

- [ ] 9.1 Controleer monitor layout in Hyprland voor eDP-1 en DVI-I-1 (DisplayLink)
- [ ] 9.2 Pas monitor config aan in `hyprland.nix` indien nodig
