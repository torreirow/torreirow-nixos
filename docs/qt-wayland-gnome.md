# Qt/Wayland + GNOME desktop (lobos, historie)

QT_QPA_PLATFORM/Electron-fixes, de Wayland-tijdlijn, Super+L-keybinding en de Strawberry-migratie. Let op: lobos draait inmiddels Hyprland; dit is grotendeels GNOME-historie.

> Verplaatst uit CLAUDE.md (Huidige Status) om de sessie-context slank te houden.

## Super+L lock-keybinding

### Sessie 2026-04-08 - Super+L Lock Keybinding - OPGELOST

**Probleem:** Super+L werkte niet om het scherm te locken (er gebeurde niets bij indrukken).

**Diagnose:**
- Keybinding was correct ingesteld: `gsettings` toonde `<Super>l` gebonden aan screensaver actie
- Lock functionaliteit werkte wel via handmatige commando's (`loginctl lock-session`)
- ScreenSaver D-Bus service was actief en werkend
- Probleem: Een GNOME extensie onderschepte de Super+L key event voordat deze de media-keys handler bereikte

**Oorzaak:**
- De extensie **highlight-focus@pimsnel.com** onderschept Super+L keybindings
- Diverse andere extensions (dash-to-panel, search-light, etc.) veroorzaakten GEEN problemen

**Oplossing (toegepast):**
```bash
gnome-extensions disable highlight-focus@pimsnel.com
```

**Status:**
- [x] highlight-focus@pimsnel.com uitgeschakeld
- [x] Super+L werkt nu correct voor screen lock
- [x] Alle andere extensions blijven actief (dash-to-panel, search-light, clipboard-history, etc.)

**Werkende extensions:**
- dash-to-panel (met hotkeys-overlay-combo='NEVER')
- search-light
- clipboard-history
- GPaste
- caffeine
- focus-changer
- window-on-top
- mediacontrols
- appindicatorsupport
- date-menu-formatter

## Qt/Wayland fixes

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

## Tijdlijn Wayland/Qt wijzigingen

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

## Strawberry (Clementine-migratie)

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

## Config: gnome-wayland.nix + programs.nix

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

## Commandos: Strawberry

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

## Commandos: Qt/Wayland testing

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
