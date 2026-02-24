# Claude Code Werkdocument - torreirow-nixos

**Laatst bijgewerkt:** 2026-02-24 (16:00)

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
- [ ] Uitloggen en opnieuw inloggen (om sessionVariables permanent te laden)
- [ ] Test apps zonder environment variable prefix

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
- **Branch:** main (28 commits achter origin, met staged changes)
- **Staged files:**
  - `CLAUDE.md` (nieuw)
  - `hosts/lobos/configuration.nix` (gewijzigd)
  - `hosts/lobos/gnome-wayland.nix` (nieuw)
  - `hosts/lobos/gnome.nix` (verwijderd)
  - `home/gnome-desktop/default.nix` (gewijzigd)
  - `todo-wouter.md` (nieuw)
- **Backup branch:** `backup-before-reset-2026-02-24`

## Te doen

- [ ] Uitloggen en opnieuw inloggen
- [ ] Test Clementine en mscore zonder environment variable prefix
- [ ] Commit de wijzigingen
- [ ] Beslissen of wijzigingen naar remote gepusht moeten worden
- [ ] Overweeg Flatpak MuseScore te verwijderen (`flatpak uninstall org.musescore.MuseScore`)

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
```

## Systeem Informatie

### Lobos (Desktop)
- **OS:** NixOS 25.11
- **Desktop:** GNOME 49.2 (Wayland)
- **Mutter:** 49.2

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
