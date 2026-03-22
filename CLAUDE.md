# Claude Code Werkdocument - torreirow-nixos

**Laatst bijgewerkt:** 2026-03-22

## Huidige Status

### Sessie 2026-02-25 - Qt/Wayland fixes - OPGELOST

**Probleem:** Qt apps (Clementine, MuseScore) gaven geen venster op GNOME 49.2 Wayland.

**Diagnose:**
- Qt5 warning: `Warning: Ignoring XDG_SESSION_TYPE=wayland on Gnome. Use QT_QPA_PLATFORM=wayland to run on Wayland anyway.`
- Zonder expliciete `QT_QPA_PLATFORM` setting faalt Qt silently en verschijnt geen venster
- `QT_QPA_PLATFORM=xcb` werkte NIET (werd genegeerd)
- `QT_QPA_PLATFORM=wayland` werkt WEL

**Oplossing (toegepast):**
Alle GNOME/Wayland settings zijn nu geconsolideerd in `hosts/lobos/gnome-wayland.nix`:

```nix
# Mutter experimental features
services.desktopManager.gnome.extraGSettingsOverrides = ''
  [org/gnome/mutter]
  experimental-features=['scale-monitor-framebuffer', 'xwayland-native-scaling']
  center-new-windows=true
'';

# Qt apps (Clementine, mscore, etc.)
environment.sessionVariables = {
  QT_QPA_PLATFORM = "wayland";
};

# Electron apps (Bitwarden, VSCode, Signal, etc.)
environment.variables = {
  ELECTRON_OZONE_PLATFORM_HINT = "wayland";
};
```

**Status:**
- [x] Nieuwe `hosts/lobos/gnome-wayland.nix` aangemaakt met alle GNOME/Wayland settings
- [x] Oude `hosts/lobos/gnome.nix` verwijderd
- [x] Duplicaten uit `hosts/lobos/configuration.nix` verwijderd
- [x] `sudo nixos-rebuild switch --flake .#lobos` succesvol uitgevoerd
- [x] Clementine werkt met `QT_QPA_PLATFORM=wayland`
- [x] NixOS MuseScore (`mscore` 4.4.3) werkt met `QT_QPA_PLATFORM=wayland`

### MuseScore: Flatpak vs NixOS

| Versie | Platform | Status |
|--------|----------|--------|
| Flatpak 4.6.3 | Hardcodes xcb | **WERKT NIET** - negeert `QT_QPA_PLATFORM` |
| NixOS 4.4.3 (`mscore`) | Respecteert env var | **WERKT** met `QT_QPA_PLATFORM=wayland` |

**Aanbeveling:** Gebruik de NixOS versie (`mscore`) in plaats van Flatpak.

### Tijdlijn Wayland/Qt wijzigingen

Volledige chronologie van Wayland en Qt configuratiewijzigingen:

#### **26 januari 2026** - Electron Wayland fixes (commit `615209a`)
**Eerste Wayland fixes voor Electron apps**

- **Probleem:** Bitwarden en andere Electron apps toonden geen window op GNOME 49.2 Wayland
- **Oplossing:**
  - `ELECTRON_OZONE_PLATFORM_HINT = "wayland"` toegevoegd aan `hosts/lobos/configuration.nix:452`
  - Nieuwe file `home/gnome-desktop/wayland-fixes.nix` met Mutter experimental features
  - Mutter settings: `scale-monitor-framebuffer` en `center-new-windows`
- **Beïnvloed:** Bitwarden, VSCode, Signal, Slack, Teams, etc.

#### **18 februari 2026** - Eerste Qt Wayland poging (commit `87e61ec`)
**Clementine wrapper met QT_QPA_PLATFORM**

- **Benadering:** Wrapper in `hosts/lobos/programs.wouter` die Clementine start met `QT_QPA_PLATFORM=wayland`
- **Status:** Experimenteel, niet de uiteindelijke oplossing

#### **24 februari 2026** - Definitieve Qt oplossing (commit `2c85dce`)
**Nieuwe gnome-wayland.nix met systeem-brede Qt Wayland support**

- **Belangrijkste wijzigingen:**
  - Nieuwe file `hosts/lobos/gnome-wayland.nix` aangemaakt
  - `environment.sessionVariables.QT_QPA_PLATFORM = "wayland"` (systeem-breed)
  - `environment.variables.ELECTRON_OZONE_PLATFORM_HINT = "wayland"` verplaatst naar gnome-wayland.nix
  - Alle GNOME/Wayland settings geconsolideerd in één bestand
  - Oude gnome.nix uitgecommentarieerd/verwijderd
- **Resultaat:** Qt apps (Clementine, MuseScore) werken nu correct op Wayland

#### **4 maart 2026** - Kleine aanpassingen (commit `82411bb`)
**Opruimen gnome-wayland.nix**

- Enkele GNOME extensions verwijderd/aangepast
- `wl-clipboard` toegevoegd
- `programs.dconf.enable = true` toegevoegd

#### **14 maart 2026** - Documentatie update (commit `ee6189d`)
**CLAUDE.md bijgewerkt met volledige Qt/Wayland documentatie**

**Huidige configuratie:**
```nix
# Qt apps (Clementine, mscore, Strawberry, etc.)
environment.sessionVariables = {
  QT_QPA_PLATFORM = "wayland";
};

# Electron apps (Bitwarden, VSCode, Signal, etc.)
environment.variables = {
  ELECTRON_OZONE_PLATFORM_HINT = "wayland";
};
```

**Impact:**
- ✅ Alle Qt apps draaien native op Wayland
- ✅ Alle Electron apps draaien native op Wayland
- ✅ Geen invisible window problemen meer
- ✅ Betere performance (geen XWayland overhead)

### Sessie 2026-02-18 - Strawberry & Fail2ban

#### 1. Clementine → Strawberry migratie (lobos)
- **Probleem:** Clementine had database corruptie ("duplicate column name: skipcount")
- **Oplossing:** Database hersteld vanuit backup
- **Ontdekt:** Clementine werkte alleen met Wayland, niet met X11
- **Beslissing:** Gemigreerd naar Strawberry (actieve fork, native Wayland support)

**Bestanden gewijzigd:**
- `hosts/lobos/programs.nix`: `clementine` vervangen door `strawberry`
- `~/.config/Clementine/clementine.db`: Hersteld vanuit backup
- Internetradio's toegevoegd aan Strawberry database (6 streams)

**Radio streams in Strawberry:**
1. SevenFM - https://25583.live.streamtheworld.com/SEVENFMAAC.aac
2. Bright FM - https://brightfm.hdsserver.net/stream
3. Christian Regular - http://stream-14.aiir.com/o8yaycnysb6tv
4. RFM Portugal - http://27793.live.streamtheworld.com/RFMAAC.aac
5. UCB 2 - https://listen-ucb.sharp-stream.com/55_ucb_2_48_aac
6. Bright FM Plus - http://brightplus.hdsserver.net/stream

#### 2. Fail2ban configuratie (malandro)
- **Nieuw bestand:** `modules/fail2ban.nix`
- **Status:** Module aangemaakt en toegevoegd aan malandro configuratie

**Configuratie details:**
- SSH jail: 5 pogingen binnen 10 min → 10 min ban
- Nginx jails: Automatisch actief als nginx enabled is
- Whitelist: 192.168.2.0/24 (lokaal netwerk)
- Backend: systemd (automatisch, geen expliciete configuratie nodig)

**NixOS 25.11 specifiek:**
- ❌ `services.fail2ban.backend` bestaat niet meer
- ❌ `services.fail2ban.maxretry` bestaat niet op top-level
- ❌ `services.fail2ban.bantime` bestaat niet op top-level
- ❌ `services.fail2ban.findtime` bestaat niet op top-level
- ✅ Deze opties werken WEL binnen jail configuraties
- ✅ `ignoreIP`, `banaction`, `banaction-allports` werken op top-level

### Sessie 2026-03-22 - Hyprland Desktop Environment

**Toegevoegd:** Hyprland window manager als parallel desktop environment naast GNOME.

**Wat is geïmplementeerd:**
- Hyprland tiling window manager met LinuxBeginnings-inspired theming
- GDM session selector voor switchen tussen GNOME en Hyprland
- Catppuccin color scheme (dark blue/purple)
- Complete Wayland native support voor alle apps

**System-Level configuratie:**
- `hosts/lobos/hyprland.nix` - Hyprland core (UWSM, portals, system packages)
- `hosts/lobos/configuration.nix` - Import hyprland.nix toegevoegd
- `hosts/lobos/programs.nix` - Hyprland packages (waybar, rofi, dunst, swaylock, etc.)

**Home Manager configuratie:**
- `home/hyprland-desktop/default.nix` - Import coordinator
- `home/hyprland-desktop/hyprland-config.nix` - Main config (keybinds, monitors, animations)
- `home/hyprland-desktop/waybar.nix` - Status bar met Catppuccin styling
- `home/hyprland-desktop/rofi.nix` - Application launcher (Arc-Dark theme)
- `home/hyprland-desktop/theme.nix` - GTK/Qt theming (Adwaita-dark, Papirus, Bibata cursor)
- `home/hyprland-desktop/swaylock.nix` - Screen locker met auto-lock (5min idle)
- `home/hyprland-desktop/dunst.nix` - Notification daemon
- `home/linux-desktop.nix` - Import hyprland-desktop module toegevoegd

**Features:**
- ✅ Dual monitor support (eDP-1 1920x1200 + DVI-I-1 1920x1080)
- ✅ Qt Wayland per-session (`QT_QPA_PLATFORM=wayland` in Hyprland config)
- ✅ Tiling window manager met dwindle layout
- ✅ Smooth animations met bezier curves
- ✅ Auto-lock na 5 minuten idle, screen off na 10 minuten
- ✅ Screenshot support (Print key → clipboard, Shift+Print → file)
- ✅ Media keys (volume, brightness, playback)
- ✅ GNOME blijft volledig intact en ongewijzigd

**Keybindings (Hyprland):**
- `SUPER+RETURN` - Terminal (alacritty)
- `SUPER+D` - Rofi launcher
- `SUPER+E` - File manager (nautilus)
- `SUPER+B` - Browser (firefox)
- `SUPER+Q` - Venster sluiten
- `SUPER+F` - Fullscreen
- `SUPER+V` - Toggle floating
- `SUPER+L` - Lock screen
- `SUPER+1-9` - Switch workspace
- `SUPER+SHIFT+1-9` - Move window to workspace
- `SUPER+Arrow keys` - Focus verplaatsen
- `SUPER+Mouse L/R` - Venster verplaatsen/resizen
- `Print` - Screenshot selectie → clipboard
- `Shift+Print` - Screenshot → ~/Pictures/
- `SUPER+SHIFT+E` - Exit Hyprland

**Sessie Switchen:**

Bij login kan je kiezen tussen GNOME en Hyprland:
1. GDM login scherm
2. Klik op gear icon (tandwiel) rechtsonder
3. Selecteer "Hyprland" of "GNOME"
4. Login met wachtwoord
5. Keuze blijft bewaard voor volgende logins

**Activeren/Deactiveren:**

```bash
# Hyprland is ACTIEF (huidige status)
# Switchen gebeurt via GDM session selector bij login

# DEACTIVEREN: Hyprland volledig uitzetten
# Edit: hosts/lobos/configuration.nix
# Comment uit: ./hyprland.nix

# Edit: home/linux-desktop.nix
# Comment uit: ./hyprland-desktop

# Rebuild:
sudo nixos-rebuild switch --flake .#lobos
home-manager switch --flake .#wtoorren@linuxdesktop --impure

# REACTIVEREN: Hyprland weer aanzetten
# Uncomment de imports weer
# Run rebuild commands opnieuw

# ROLLBACK naar vorige generatie:
sudo nixos-rebuild switch --rollback
home-manager switch --flake .#wtoorren@linuxdesktop --impure --rollback
```

**Status:** ACTIEF - Beide GNOME en Hyprland beschikbaar via GDM session selector

**Commit:** `6aaa684` - Add Hyprland window manager alongside GNOME

## Configuratie bestanden

### hosts/lobos/gnome-wayland.nix

Bevat alle GNOME/Mutter/Wayland settings:
- `services.xserver.enable`
- `services.displayManager.gdm.enable`
- `services.desktopManager.gnome.enable`
- `services.desktopManager.gnome.extraGSettingsOverrides` (Mutter features)
- `xdg.portal` configuratie
- `environment.sessionVariables.QT_QPA_PLATFORM`
- `environment.variables.ELECTRON_OZONE_PLATFORM_HINT`
- GNOME extensions packages

### hosts/lobos/programs.nix

- Strawberry (muziekspeler)
- Spotify wrapper met Wayland support
- nixvim via flake input

## Systeem Informatie

### Lobos (Desktop)
- **OS:** NixOS 25.11
- **Desktop Environments:**
  - GNOME 49.2 (Wayland) - Mutter 49.2
  - Hyprland (Wayland) - Tiling WM met Catppuccin theme
  - Switch via GDM session selector
- **Display:** Dual monitor (eDP-1 1920x1200 + DVI-I-1 1920x1080)
- **Muziekspeler:** Strawberry

### Malandro (Server)
- **OS:** NixOS 25.11
- **Services:** Nginx, Home Assistant, Grafana, Paperless, Vaultwarden, Gitea, fail2ban

## Useful Commands

### Fail2ban (malandro)
```bash
# Status van alle jails
sudo fail2ban-client status

# Details van specifieke jail
sudo fail2ban-client status sshd
sudo fail2ban-client status nginx-http-auth

# Gebande IPs
sudo fail2ban-client banned

# Logs volgen
sudo journalctl -u fail2ban -f

# IP handmatig bannen/unbannen
sudo fail2ban-client set sshd banip 1.2.3.4
sudo fail2ban-client set sshd unbanip 1.2.3.4
```

### Strawberry (lobos)
```bash
# Strawberry starten
strawberry

# Database locatie
~/.local/share/strawberry/strawberry/strawberry.db

# Config locatie
~/.config/strawberry/strawberry.conf

# Radio streams toevoegen (SQL)
sqlite3 ~/.local/share/strawberry/strawberry/strawberry.db \
  "INSERT INTO radio_channels (source, name, url) VALUES (0, 'Name', 'http://url');"
```

### NixOS rebuild
```bash
# Lobos
sudo nixos-rebuild switch --flake .#lobos

# Malandro (remote)
sudo nixos-rebuild switch --flake .#malandro

# Met trace voor debugging
sudo nixos-rebuild switch --flake .#malandro --show-trace

# Dry run (test zonder changes)
sudo nixos-rebuild dry-build --flake .#malandro

# Home-manager (lobos)
home-manager switch --flake .#wtoorren@linuxdesktop --extra-experimental-features nix-command -b backup-$(date +%s) --impure
```

### Qt/Wayland testing
```bash
# Test Qt app met specifiek platform
QT_QPA_PLATFORM=wayland strawberry
QT_QPA_PLATFORM=wayland mscore

# Check huidige environment
echo $QT_QPA_PLATFORM  # zou "wayland" moeten tonen

# Flatpak beheer
flatpak list --app
flatpak uninstall org.musescore.MuseScore
```

### Hyprland (lobos)
```bash
# Check welke desktop sessie actief is
echo $XDG_CURRENT_DESKTOP  # "Hyprland" of "GNOME"

# Hyprland control (alleen in Hyprland sessie)
hyprctl monitors                    # Monitor info
hyprctl clients                     # Open windows
hyprctl workspaces                  # Workspace info
hyprctl dispatch dpms off           # Screen uit
hyprctl dispatch dpms on            # Screen aan
hyprctl reload                      # Reload config

# Waybar control (in Hyprland)
systemctl --user status waybar      # Waybar status
systemctl --user restart waybar     # Waybar herstarten
killall -SIGUSR2 waybar             # Waybar reload

# Screenshots (in Hyprland)
grim -g "$(slurp)" - | wl-copy      # Selectie naar clipboard
grim ~/Pictures/screenshot.png      # Full screen naar file

# Lock screen
swaylock                            # Handmatig locken
# Auto-lock na 5 minuten idle (via swayidle)

# Switch tussen GNOME en Hyprland
# Logout → GDM login → gear icon → selecteer sessie
```

### Git
```bash
git status
git diff --staged
git log --oneline -10
```

## File Locations

### Config bestanden
- **Lobos:** `hosts/lobos/`
  - `configuration.nix` - Main config
  - `gnome-wayland.nix` - GNOME/Wayland settings
  - `hyprland.nix` - Hyprland system config (portals, packages)
  - `programs.nix` - Packages (GEBRUIKT)

- **Lobos Home Manager:** `home/`
  - `linux-desktop.nix` - Main imports (gnome-desktop, hyprland-desktop)
  - `gnome-desktop/` - GNOME user config
  - `hyprland-desktop/` - Hyprland user config
    - `hyprland-config.nix` - Main Hyprland settings
    - `waybar.nix` - Status bar
    - `rofi.nix` - Launcher
    - `theme.nix` - GTK/Qt theming
    - `swaylock.nix` - Screen locker
    - `dunst.nix` - Notifications

- **Malandro:** `hosts/malandro/`
  - `configuration.nix` - Main config
  - `programs.nix` - Packages

### Modules
- `modules/fail2ban.nix` - Fail2ban configuratie
- `modules/monitoring/` - Grafana/Prometheus
- `modules/nginx.nix` - Nginx config
- Zie `hosts/malandro/configuration.nix` imports voor volledige lijst
