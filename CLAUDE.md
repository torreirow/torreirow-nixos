# Claude Code Werkdocument - torreirow-nixos

<<<<<<< HEAD
**Laatst bijgewerkt:** 2026-02-18

## Huidige Status

### ✅ Voltooid in deze sessie

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

**Backups:**
- `~/.config/Clementine.old-broken/` - Oude Clementine config met werkende database
- `~/.config/Clementine.backup-20260218-115634/` - Extra backup

**Te doen:**
- [ ] `sudo nixos-rebuild switch` uitvoeren op lobos om Strawberry permanent te installeren
- [ ] Oude Clementine backups verwijderen na bevestiging dat alles werkt

#### 2. Fail2ban configuratie (malandro)
- **Nieuw bestand:** `modules/fail2ban.nix`
- **Status:** Module aangemaakt en toegevoegd aan malandro configuratie

**Configuratie details:**
- SSH jail: 5 pogingen binnen 10 min → 10 min ban
- Nginx jails: Automatisch actief als nginx enabled is
- Whitelist: 192.168.2.0/24 (lokaal netwerk)
- Backend: systemd (automatisch, geen expliciete configuratie nodig)

**Bestanden gewijzigd:**
- `modules/fail2ban.nix` - Nieuwe module aangemaakt
- `hosts/malandro/configuration.nix` - fail2ban.nix import toegevoegd

**NixOS 25.11 specifiek:**
- ❌ `services.fail2ban.backend` bestaat niet meer
- ❌ `services.fail2ban.maxretry` bestaat niet op top-level
- ❌ `services.fail2ban.bantime` bestaat niet op top-level
- ❌ `services.fail2ban.findtime` bestaat niet op top-level
- ✅ Deze opties werken WEL binnen jail configuraties
- ✅ `ignoreIP`, `banaction`, `banaction-allports` werken op top-level

**Te doen:**
- [ ] `sudo nixos-rebuild switch --flake .#malandro` uitvoeren
- [ ] Fail2ban testen met: `sudo fail2ban-client status`
- [ ] Fail2ban jails bekijken: `sudo fail2ban-client status sshd`

### ⚠️ Notities

#### Cockpit monitoring
- Cockpit heeft **geen native fail2ban visualisatie**
- Fail2ban monitoring via SSH: `sudo fail2ban-client status`
- Alternatief: Grafana (al geconfigureerd op malandro)

#### programs.wouter vs programs.nix (lobos)
- `configuration.nix` importeert `./programs.nix` (NIET programs.wouter)
- `programs.wouter` wordt momenteel niet gebruikt
- Strawberry is toegevoegd aan `programs.nix`

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
sudo nixos-rebuild switch

# Malandro (remote)
sudo nixos-rebuild switch --flake .#malandro

# Met trace voor debugging
sudo nixos-rebuild switch --flake .#malandro --show-trace

# Dry run (test zonder changes)
sudo nixos-rebuild dry-build --flake .#malandro
```

## File Locations

### Config bestanden
- **Lobos:** `hosts/lobos/`
  - `configuration.nix` - Main config
  - `programs.nix` - Packages (GEBRUIKT)
  - `programs.wouter` - (NIET GEBRUIKT)

- **Malandro:** `hosts/malandro/`
  - `configuration.nix` - Main config
  - `programs.nix` - Packages

### Modules
- `modules/fail2ban.nix` - Fail2ban configuratie
- `modules/monitoring/` - Grafana/Prometheus
- `modules/nginx.nix` - Nginx config
- Zie `hosts/malandro/configuration.nix` imports voor volledige lijst

## Git Status

```bash
# Modified files (uncommitted):
- hosts/lobos/programs.nix (Strawberry toegevoegd)
- hosts/lobos/programs.wouter (Niet gebruikt, kan teruggedraaid worden)
- hosts/malandro/configuration.nix (fail2ban.nix import toegevoegd)
- modules/fail2ban.nix (Nieuw bestand)
- modules/magister/magister_session.json (Auto-update)
=======
**Laatst bijgewerkt:** 2026-02-25

## Huidige Status

### Sessie 2026-02-24 (middag) - OPGELOST

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
- [x] Uitloggen en opnieuw inloggen (om sessionVariables permanent te laden)
- [x] Test apps zonder environment variable prefix

### MuseScore: Flatpak vs NixOS

| Versie | Platform | Status |
|--------|----------|--------|
| Flatpak 4.6.3 | Hardcodes xcb | **WERKT NIET** - negeert `QT_QPA_PLATFORM` |
| NixOS 4.4.3 (`mscore`) | Respecteert env var | **WERKT** met `QT_QPA_PLATFORM=wayland` |

**Aanbeveling:** Gebruik de NixOS versie (`mscore`) in plaats van Flatpak.

### Refactoring configuratie

De GNOME/Wayland configuratie is gerefactored:

**Voorheen:** Settings verspreid over `configuration.nix` en niet-actieve `gnome.nix`

**Nu:** Alles geconsolideerd in `gnome-wayland.nix`:
- GNOME desktop services (gdm, gnome-settings-daemon)
- Mutter experimental features
- XDG portals
- Wayland environment variables (Qt + Electron)
- GNOME extensions en packages

### Git Status
- **Branch:** main (gesynchroniseerd met origin)
- **Laatste commit:** `2c85dce fix flatpak and x11-on-wayland apps`
- **Backup branch:** `backup-before-reset-2026-02-24` (oude staat voor reset)

## Te doen

Alle taken zijn afgerond.

## Configuratie bestanden

### hosts/lobos/gnome-wayland.nix (NIEUW)

Bevat alle GNOME/Mutter/Wayland settings:
- `services.xserver.enable`
- `services.displayManager.gdm.enable`
- `services.desktopManager.gnome.enable`
- `services.desktopManager.gnome.extraGSettingsOverrides` (Mutter features)
- `xdg.portal` configuratie
- `environment.sessionVariables.QT_QPA_PLATFORM`
- `environment.variables.ELECTRON_OZONE_PLATFORM_HINT`
- GNOME extensions packages

### hosts/lobos/configuration.nix

Opgeschoond - GNOME settings verwijderd, verwijst nu naar `gnome-wayland.nix` via import.

## Handmatig testen (voor uitloggen)

```bash
# Test Clementine met wayland
QT_QPA_PLATFORM=wayland clementine

# Test NixOS MuseScore (WERKT)
QT_QPA_PLATFORM=wayland mscore

# Test Flatpak MuseScore (WERKT NIET - hardcodes xcb)
flatpak run org.musescore.MuseScore
```

## Na uitloggen/inloggen

```bash
# Apps zouden nu moeten werken zonder prefix
clementine
mscore

# Check environment
echo $QT_QPA_PLATFORM  # zou "wayland" moeten tonen
```

## Herstel instructies

Als Qt apps nog steeds niet werken na de fix:
```bash
# Probeer xcb fallback
QT_QPA_PLATFORM=xcb clementine

# Of verwijder de setting en laat Qt zelf kiezen
# (comment out QT_QPA_PLATFORM in gnome-wayland.nix)
```

Terug naar backup git staat:
```bash
git reset --hard backup-before-reset-2026-02-24
>>>>>>> 4fbe135b46a242f8b61ec10adaf4eae8ace0f155
```

## Systeem Informatie

### Lobos (Desktop)
- **OS:** NixOS 25.11
<<<<<<< HEAD
- **Desktop:** GNOME (Wayland)
- **Display:** Dual monitor (eDP-1 1920x1200 + DVI-I-1 1920x1080)
- **Muziekspeler:** Strawberry (was Clementine)
=======
- **Desktop:** GNOME 49.2 (Wayland)
- **Mutter:** 49.2
>>>>>>> 4fbe135b46a242f8b61ec10adaf4eae8ace0f155

### Malandro (Server)
- **OS:** NixOS 25.11
- **Services:** Nginx, Home Assistant, Grafana, Paperless, Vaultwarden, Gitea, etc.

## Useful Commands

```bash
# NixOS rebuild
sudo nixos-rebuild switch --flake .#lobos

# Test Qt app met specifiek platform
QT_QPA_PLATFORM=wayland clementine
QT_QPA_PLATFORM=wayland mscore

# Check huidige environment
echo $QT_QPA_PLATFORM

# Git
git status
git diff --staged
git log backup-before-reset-2026-02-24 --oneline

# Flatpak beheer
flatpak list --app
flatpak uninstall org.musescore.MuseScore
```
- bij uitvoeren home-manager commandos op lobos:  home-manager  switch --flake .#wtoorren@linuxdesktop --extra-experimental-features nix-command -b backup-$(date +%s) --impure
