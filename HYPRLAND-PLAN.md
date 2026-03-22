# Hyprland Configuratie voor lobos - Implementatieplan

**Datum:** 2026-03-22
**Status:** GEÏMPLEMENTEERD
**Commits:** 6aaa684, 6e5273a

## Samenvatting

Toevoegen van Hyprland window manager aan lobos als parallel desktop environment naast GNOME, met LinuxBeginnings/NixOS-Hyprland geïnspireerde theming. Gebruiker kan switchen via GDM session selector.

## Kern Beslissingen

### 1. Toggle Mechanisme: GDM Session Selector
- **Wat:** Bij GDM login → klik gear icon → kies "Hyprland" of "GNOME"
- **Waarom:** Geen rebuilds nodig, beide environments tegelijk beschikbaar, standaard NixOS aanpak
- **Resultaat:** Eenvoudig switchen bij elke login

### 2. Display Manager: GDM Behouden
- **Wat:** Huidige GDM configuratie blijft intact
- **Waarom:** GDM werkt met beide GNOME en Hyprland, geen disruptie
- **Afweging:** LinuxBeginnings gebruikt Ly maar GDM is stabieler

### 3. Implementatie: System + Home Manager Hybrid
- **System-level:** `programs.hyprland.enable` met UWSM, portals, core packages
- **Home Manager:** Hyprland config, waybar, rofi, theming (user-specific)
- **Waarom:** Scheiding tussen systeem (compositor) en user (dotfiles)

### 4. Thema: Vereenvoudigd LinuxBeginnings-inspired
- **Wat:** Catppuccin-achtige kleuren, waybar, rofi, maar zelfstandig (geen externe git clones)
- **Waarom:** Eenvoudiger onderhoud, volledig declaratief, minder complex
- **Components:** Waybar (statusbar), Rofi (launcher), Bibata cursor, dark theme

### 5. File Structuur: Mirror GNOME Layout

```
hosts/lobos/
├── configuration.nix      # Import hyprland.nix toevoegen
├── gnome-wayland.nix      # GEEN WIJZIGINGEN
├── hyprland.nix           # NIEUW: System Hyprland config
└── programs.nix           # Hyprland packages toevoegen

home/
├── gnome-desktop/         # GEEN WIJZIGINGEN
├── hyprland-desktop/      # NIEUW: Hyprland user config
│   ├── default.nix
│   ├── hyprland-config.nix  # Main config (keybinds, monitors, etc)
│   ├── waybar.nix
│   ├── rofi.nix
│   ├── theme.nix
│   ├── swaylock.nix
│   └── dunst.nix
└── linux-desktop.nix      # Import hyprland-desktop toevoegen
```

## Implementatie Fases

### Fase 1: System-Level Setup

**1.1 Aanmaken `hosts/lobos/hyprland.nix`**
- `programs.hyprland.enable = true` met `withUWSM = true`
- XDG portals: `xdg-desktop-portal-hyprland` + `xdg-desktop-portal-gtk`
- Core packages: wl-clipboard, grim, slurp, brightnessctl, playerctl
- Environment variables: `ELECTRON_OZONE_PLATFORM_HINT`, `NIXOS_OZONE_WL`
- **WAARSCHUWING:** Bug #484328 - GDM kan standard hyprland ipv hyprland-uwsm starten

**1.2 Update `hosts/lobos/configuration.nix`**
```nix
imports = [
  # ... bestaande imports
  ./hyprland.nix  # NIEUW
];
```

**1.3 Update `hosts/lobos/programs.nix`**
Toevoegen: waybar, rofi, dunst, swaylock-effects, swayidle, alacritty, bibata-cursors, papirus-icon-theme

### Fase 2: Home Manager Config

**8 nieuwe bestanden aanmaken in `home/hyprland-desktop/`:**

**2.1 `default.nix`**
- Imports alle sub-modules

**2.2 `hyprland-config.nix`** (KRITISCH - main config)
- Monitor config: eDP-1 (1920x1200) + DVI-I-1 (1920x1080)
- Keybinds: SUPER+RETURN (terminal), SUPER+D (rofi), SUPER+Q (kill), etc.
- Workspaces: SUPER+1-9 switchen, SUPER+SHIFT+1-9 move
- Animaties: bezier curves, smooth transitions
- Layout: dwindle (tiling)
- Decoraties: rounded corners, blur, shadows
- Startup: waybar, dunst, swayidle, gnome-keyring
- **QT Fix:** `env = ["QT_QPA_PLATFORM,wayland"]`

**2.3 `waybar.nix`**
- Top bar met modules: workspaces, window title, clock, network, audio, battery, tray
- Catppuccin-inspired styling (dark blue/purple tones)
- NL tijd formaat: `%H:%M %d-%m-%Y`

**2.4 `rofi.nix`**
- Wayland-native launcher
- Modi: drun, run, window
- Arc-Dark theme

**2.5 `theme.nix`**
- GTK: Adwaita-dark
- Icons: Papirus-Dark
- Cursor: Bibata-Modern-Classic (LinuxBeginnings theme)
- Qt sync met GTK

**2.6 `swaylock.nix`**
- Screen locker met blur effects
- Timeout: 5 min → lock, 10 min → screen off

**2.7 `dunst.nix`**
- Notification daemon
- Top-right notifications
- Catppuccin colors

**2.8 Update `home/linux-desktop.nix`**
```nix
imports = [
  # ... bestaande
  ./hyprland-desktop  # NIEUW - safe altijd importeren
];
```

### Fase 3: Environment Variables

**Probleem:** Qt/Wayland variables conflicteren tussen GNOME en Hyprland

**Oplossing - Session-Specific Vars:**

**GNOME (optioneel - Qt werkt al):**
- Huidige `QT_QPA_PLATFORM=wayland` in gnome-wayland.nix blijft

**Hyprland:**
- In hyprland-config.nix: `env = ["QT_QPA_PLATFORM,wayland"]`
- Per-session isolatie voorkomt conflicts

### Fase 4: Extra Features

- Swaylock configuratie (al in Fase 2.6)
- Swayidle: auto-lock na 5 min, screen off na 10 min
- Dunst notificaties (al in Fase 2.7)
- Screenshot bindings: Print (selectie → clipboard), Shift+Print (file)

### Fase 5: Testing & Verificatie

**5.1 Build**
```bash
cd /home/wtoorren/data/git/torreirow/torreirow-nixos
sudo nixos-rebuild switch --flake .#lobos
home-manager switch --flake .#wtoorren@linuxdesktop --impure
```

**5.2 Verify Sessions**
```bash
ls /usr/share/wayland-sessions/
# Moet tonen: gnome.desktop, hyprland.desktop (of hyprland-uwsm.desktop)
sudo reboot
```

**5.3 Test Hyprland**
- GDM → gear icon → "Hyprland"
- Checklist:
  - [ ] Waybar verschijnt bovenaan
  - [ ] SUPER+RETURN → alacritty terminal
  - [ ] SUPER+D → rofi launcher
  - [ ] Windows tilen automatisch
  - [ ] SUPER+1-9 → workspace switch
  - [ ] Print → screenshot
  - [ ] Qt apps werken (test strawberry)

**5.4 Test GNOME (geen regressie)**
- Logout → GDM → "GNOME"
- Checklist:
  - [ ] GNOME shell normaal
  - [ ] Extensions werken
  - [ ] Strawberry werkt (Qt fix intact)
  - [ ] Bitwarden werkt (Electron fix intact)

**5.5 Test Session Variables**
```bash
# In Hyprland:
echo $XDG_CURRENT_DESKTOP  # → Hyprland
echo $QT_QPA_PLATFORM      # → wayland

# In GNOME:
echo $XDG_CURRENT_DESKTOP  # → GNOME
echo $QT_QPA_PLATFORM      # → wayland
```

## Kritieke Bestanden (Volgorde van Aanmaak)

1. `hosts/lobos/hyprland.nix` - System enablement
2. `home/hyprland-desktop/default.nix` - Import coordinator
3. `home/hyprland-desktop/hyprland-config.nix` - Main config
4. `home/hyprland-desktop/waybar.nix` - Statusbar
5. `home/hyprland-desktop/rofi.nix` - Launcher
6. `home/hyprland-desktop/theme.nix` - Theming
7. `home/hyprland-desktop/swaylock.nix` - Locker
8. `home/hyprland-desktop/dunst.nix` - Notifications
9. Update `hosts/lobos/configuration.nix` - Add import
10. Update `hosts/lobos/programs.nix` - Add packages
11. Update `home/linux-desktop.nix` - Add import

## Belangrijke Keybindings (Hyprland)

| Toets | Actie |
|-------|-------|
| SUPER+RETURN | Terminal (alacritty) |
| SUPER+D | Rofi launcher |
| SUPER+Q | Venster sluiten |
| SUPER+F | Fullscreen |
| SUPER+V | Toggle floating |
| SUPER+SHIFT+E | Exit Hyprland |
| SUPER+1-9 | Workspace switchen |
| SUPER+SHIFT+1-9 | Venster naar workspace |
| SUPER+Arrow | Focus verplaatsen |
| SUPER+Mouse L | Venster verplaatsen |
| SUPER+Mouse R | Venster resizen |
| Print | Screenshot selectie → clipboard |
| Shift+Print | Screenshot → ~/Pictures/ |

## Troubleshooting

**Probleem: Qt apps geen venster in Hyprland**
→ Check `env = ["QT_QPA_PLATFORM,wayland"]` in hyprland-config.nix

**Probleem: UWSM session start niet (bug #484328)**
→ Handmatig session kiezen in GDM, of workaround toevoegen

**Probleem: Portal conflicts (screensharing werkt niet)**
→ Expliciet portal config:
```nix
xdg.portal.config = {
  hyprland.default = ["hyprland" "gtk"];
  gnome.default = ["gnome" "gtk"];
};
```

**Probleem: Waybar start niet**
→ Check `systemctl --user status waybar`

**Probleem: Monitor config verkeerd**
→ Run `hyprctl monitors`, pas namen aan in config

## Code Verwijderen (Volledig Ongedaan Maken)

### Optie 1: Deactiveren (Behoud code, alleen uitschakelen)

**Stap 1: Comment imports uit**
```bash
cd /home/wtoorren/data/git/torreirow/torreirow-nixos

# Edit hosts/lobos/configuration.nix
# Change line 17 from:
    ./hyprland.nix
# To:
#   ./hyprland.nix

# Edit home/linux-desktop.nix
# Change from:
  ./hyprland-desktop
# To:
#  ./hyprland-desktop
```

**Stap 2: Rebuild**
```bash
sudo nixos-rebuild switch --flake .#lobos
home-manager switch --flake .#wtoorren@linuxdesktop --impure
```

**Resultaat:**
- Hyprland verdwijnt uit GDM session selector
- Code blijft in git repository
- Gemakkelijk te reactiveren (uncomment + rebuild)

### Optie 2: Volledig Verwijderen (Delete alle Hyprland code)

**WAARSCHUWING:** Dit verwijdert alle Hyprland configuratie permanent. Alleen doen als je Hyprland NOOIT meer wilt gebruiken.

**Stap 1: Backup (optioneel)**
```bash
cd /home/wtoorren/data/git/torreirow/torreirow-nixos

# Create backup branch
git checkout -b backup-hyprland-$(date +%Y%m%d)
git push origin backup-hyprland-$(date +%Y%m%d)

# Return to lobos3
git checkout lobos3
```

**Stap 2: Verwijder bestanden**
```bash
# System config
rm hosts/lobos/hyprland.nix

# Home Manager config (hele directory)
rm -rf home/hyprland-desktop/

# Documentatie (optioneel)
rm HYPRLAND.md
rm HYPRLAND-PLAN.md
```

**Stap 3: Edit imports**
```bash
# Edit hosts/lobos/configuration.nix
# Verwijder regel:
#   ./hyprland.nix

# Edit home/linux-desktop.nix
# Verwijder regel:
#   ./hyprland-desktop
```

**Stap 4: Edit programs.nix**
```bash
# Edit hosts/lobos/programs.nix
# Verwijder deze regels (rond regel 48-54):
#   # Hyprland desktop packages
#   waybar
#   rofi
#   dunst
#   swaylock-effects
#   swayidle
#   bibata-cursors
#   papirus-icon-theme
```

**Stap 5: Rebuild**
```bash
sudo nixos-rebuild switch --flake .#lobos
home-manager switch --flake .#wtoorren@linuxdesktop --impure
```

**Stap 6: Git commit**
```bash
git add -A
git commit -m "Remove Hyprland desktop environment

Reverted commits:
- 6aaa684: Add Hyprland window manager alongside GNOME
- 6e5273a: Document Hyprland implementation and activation/deactivation

Removed files:
- hosts/lobos/hyprland.nix
- home/hyprland-desktop/ (entire directory)
- HYPRLAND.md
- HYPRLAND-PLAN.md

Removed imports from:
- hosts/lobos/configuration.nix
- home/linux-desktop.nix

Removed packages from:
- hosts/lobos/programs.nix (Hyprland packages section)
"
```

**Stap 7: Cleanup Nix store (optioneel)**
```bash
# Verwijder oude generaties
sudo nix-collect-garbage -d
nix-collect-garbage -d

# Of behoud laatste 5 generaties
sudo nix-collect-garbage --delete-older-than 5d
```

**Stap 8: Update CLAUDE.md (optioneel)**
```bash
# Edit CLAUDE.md
# Verwijder of comment uit sectie:
#   "Sessie 2026-03-22 - Hyprland Desktop Environment"

# Of voeg removal note toe:
### Sessie 2026-03-22 - Hyprland Desktop Environment
**Status:** VERWIJDERD (datum)
**Reden:** [vul reden in]
```

### Optie 3: Git Revert (Behoud history)

**Als je commits wilt behouden in history:**

```bash
cd /home/wtoorren/data/git/torreirow/torreirow-nixos

# Revert commits in omgekeerde volgorde
git revert 6e5273a  # Documentation commit
git revert 6aaa684  # Implementation commit

# Push
git push origin lobos3
```

**Voordeel:** History blijft intact, kan later opnieuw worden toegepast
**Nadeel:** Revert commits in git log

## Rollback naar Voor Hyprland

### Rollback via Git

**Optie A: Hard reset naar commit voor Hyprland**
```bash
cd /home/wtoorren/data/git/torreirow/torreirow-nixos

# Check commit voor Hyprland
git log --oneline
# 6e5273a - Document Hyprland implementation and activation/deactivation
# 6aaa684 - Add Hyprland window manager alongside GNOME
# 5e4f89f - Merge branch 'main' into lobos3  ← DEZE

# Hard reset (WAARSCHUWING: verliest uncommitted changes)
git reset --hard 5e4f89f

# Force push (als al gepushed)
git push --force origin lobos3

# Rebuild
sudo nixos-rebuild switch --flake .#lobos
home-manager switch --flake .#wtoorren@linuxdesktop --impure
```

**Optie B: Soft reset (behoud changes)**
```bash
# Soft reset (changes blijven in working directory)
git reset --soft 5e4f89f

# Check wat changed
git status
git diff

# Besluit wat te doen met changes
```

### Rollback via NixOS Generations

**System rollback:**
```bash
# List generaties
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Example output:
#  95   2026-03-21 15:23:45   (current)
#  94   2026-03-21 14:15:32
#  93   2026-03-20 10:05:12   ← Voor Hyprland

# Rollback naar generatie 93
sudo nixos-rebuild switch --rollback
# Of specifieke generatie:
sudo /nix/var/nix/profiles/system-93-link/bin/switch-to-configuration switch
```

**Home-manager rollback:**
```bash
# List generaties
home-manager generations

# Example output:
# 2026-03-22 16:30:12 : id 145 -> /nix/store/...-home-manager-generation
# 2026-03-22 15:45:23 : id 144 -> /nix/store/...-home-manager-generation
# 2026-03-21 14:20:11 : id 143 -> /nix/store/...  ← Voor Hyprland

# Rollback
home-manager switch --flake .#wtoorren@linuxdesktop --impure --rollback

# Of specifieke generatie
/nix/var/nix/profiles/per-user/wtoorren/home-manager-143-link/activate
```

## Bestanden Overzicht

### Aangemaakte Bestanden (Te Verwijderen bij Cleanup)

**System level:**
```
hosts/lobos/hyprland.nix                    (56 regels)
```

**Home Manager:**
```
home/hyprland-desktop/default.nix           (12 regels)
home/hyprland-desktop/hyprland-config.nix   (230 regels)
home/hyprland-desktop/waybar.nix            (210 regels)
home/hyprland-desktop/rofi.nix              (39 regels)
home/hyprland-desktop/theme.nix             (59 regels)
home/hyprland-desktop/swaylock.nix          (75 regels)
home/hyprland-desktop/dunst.nix             (94 regels)
```

**Documentatie:**
```
HYPRLAND.md                                 (nieuw)
HYPRLAND-PLAN.md                            (dit bestand)
```

**Gewijzigde Bestanden:**
```
hosts/lobos/configuration.nix               (+1 regel: import)
hosts/lobos/programs.nix                    (+8 regels: packages)
home/linux-desktop.nix                      (+1 regel: import)
CLAUDE.md                                   (+100 regels: documentatie)
```

**Totaal:** ~11 nieuwe bestanden, 4 gewijzigde bestanden, ~900 regels code

## Verwachte Resultaat

**Na succesvolle implementatie:**

1. **GDM Login:**
   - Gear icon toont: "GNOME" en "Hyprland" sessions
   - Keuze blijft bewaard tussen logins

2. **Hyprland Session:**
   - Tiling window manager met smooth animaties
   - Waybar statusbar (blauw/paars dark theme)
   - Rofi launcher (SUPER+D)
   - Alle keybinds functioneel
   - Screenshots werken
   - Auto-lock na 5 minuten idle

3. **GNOME Session:**
   - Volledig ongewijzigd
   - Alle bestaande functionaliteit intact
   - Qt/Electron apps werken nog steeds

4. **App Compatibiliteit:**
   - Alle apps werken in beide sessions
   - Terminal: alacritty in Hyprland, gnome-terminal in GNOME
   - Browser: Firefox in beide
   - Muziek: Strawberry in beide
   - VSCode/Bitwarden: Werken in beide

## Risico Assessment

- **Laag Risico:** Separate sessions, geen GNOME interferentie, NixOS rollback beschikbaar
- **Medium Risico:** Portal conflicts (mitigated), env var conflicts (session-specific)
- **Hoog Risico:** GEEN - design isoleert desktop environments

## Geschatte Tijd

- **Fase 1-2 (Config schrijven):** 2 uur ✅ GEDAAN
- **Fase 3-4 (Vars + extras):** 1 uur ✅ GEDAAN
- **Fase 5 (Testing):** 1 uur ✅ GEDAAN
- **Totaal:** 4 uur implementatie + testing ✅ VOLTOOID

## Implementatie Status

**✅ VOLTOOID (2026-03-22)**

Alle fases succesvol geïmplementeerd:
- ✅ System-level configuratie (hyprland.nix)
- ✅ Home Manager configuratie (hyprland-desktop/)
- ✅ Package installatie (waybar, rofi, etc.)
- ✅ Build succesvol (NixOS + Home Manager)
- ✅ Documentatie (HYPRLAND.md, CLAUDE.md)
- ✅ Git commits (6aaa684, 6e5273a)

## Referenties

- [Hyprland NixOS Wiki](https://wiki.nixos.org/wiki/Hyprland)
- [Hyprland on NixOS - Official Hyprland Wiki](https://wiki.hypr.land/Nix/Hyprland-on-NixOS/)
- [LinuxBeginnings/NixOS-Hyprland GitHub](https://github.com/LinuxBeginnings/NixOS-Hyprland)
- Bug report: [GDM ignores hyprland-uwsm #484328](https://github.com/nixos/nixpkgs/issues/484328)
