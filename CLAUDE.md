# Claude Code Werkdocument - torreirow-nixos

**Laatst bijgewerkt:** 2026-08-24

## Contextbestanden (lees on-demand)

- **Vragen over USB dongle, Zigbee dongle, DSMR adapter, `/dev/zigbee`, `/dev/dsmr` of ttyUSB-poorten die verwisselen** → lees `docs/usb-dongles.md`

## Huidige Status

### Sessie 2026-08-24 - Geurhal (WC) ir_detector-automation + timer restore - OPGELOST

**Vraag:** Bestaat er een automation die de geurhal aanzet als de "ir_detector" afgaat?

**Antwoord: ja, de keten bestaat al.** De "ir_detector" is het **WCsensor** PIR-bewegingssensor
(model "Motion sensor"; de `sensor.pir_voltage` / `sensor.pir_linkquality` entities horen bij dat
device). Geen entity heet letterlijk `ir_detector`.

**HA-opzet geurhal (WC):**
- PIR/trigger: **WCsensor** → `binary_sensor.wcsensor_occupancy` (type `occupied`)
- Plug: **Tuya Smart Plug** `switch.kerstoom3hoek_stopcontact_1` (naam "Geurhalwc", device `bfbc2e57cddcfdd03dvncw`, area hal)
- Timer: `timer.geurhaltimer` (UI-helper in `.storage/timer`, duur 1u)
- Automations in `/var/lib/homeassistant/automations.yaml`:
  - `1732536224233` "WC geur aan" → occupancy on → plug aan + `timer.geurhaltimer` start
  - `1732536276607` "WC geur uit" → `timer.finished` → plug uit

**Wijziging doorgevoerd:** `timer.geurhaltimer` → `restore: false` → **`restore: true`** in
`.storage/timer` (zelfde les als bij `timer.afzuiging`: met `false` sprong de timer bij HA-herstart
stil naar idle zonder de geurhal uit te zetten). HA (container `docker-homeassistant.service`)
herstart → waarde ingelezen en na herstart geverifieerd bewaard gebleven.
Backup: `.storage/timer.bak-claude-20260824-163206`.

**Let op:** de plug is een Tuya-apparaat. Per sessie 2026-08-23 was de Tuya-integratie kapot sinds
17 aug; user gaf aan dat Tuya het weer zou doen. Als de geurhal niet reageert terwijl de automation
wél vuurt → check eerst de Tuya-koppeling (zelfde oorzaak als bij de afzuiging).

**Status:** ✅ `restore: true` live; automation-keten compleet mits Tuya werkt.


### Sessie 2026-08-23 - Afzuiging gaat wel aan maar niet uit - DEELS OPGELOST

**Probleem:** Centrale afzuiging (keuken) ging wel aan maar niet meer automatisch uit. Knop (RODRET) deed het slecht.

**HA-opzet afzuiging:**
- Stekker: **Tuya Smart Plug** `switch.afzuiging_socket_1` (device `bf4193cbb9e7c8307efsqq`)
- Knop: **IKEA RODRET** `afzuigingknop` via zigbee2mqtt (`0x5cc7c1fffe405825`)
- Timer: `timer.afzuiging` (UI-helper in `.storage/timer`, duur 1u)
- Automations in `/var/lib/homeassistant/automations.yaml`:
  - `1771177871263` "Centrale afzuiging aan" → knop-on/switch-on → stekker aan + timer start
  - `2024112501` "Centrale afzuiging uit" → `timer.finished` → stekker uit
- Let op: entity-slugs misleidend — `automation.centrale_afzuiging_uit_2/_3/_4` zijn NIET allemaal afzuiging (uit_2 = de "aan"; uit_3/_4 = Geurzolder/Geurwerkkamer, oude slugs).

**Hoofdoorzaak (nog handmatig op te lossen):**
**Tuya-integratie kapot sinds 17 aug** — log toont `tuya_sharing ApiRequestException: sign invalid` en `API_QPS_LIMIT_OR_DEGRADE`. HA kan de Tuya-stekker niet meer betrouwbaar uitzetten of uitlezen (`binary_sensor.afzuiging_status` stond vast op `off` sinds 17 aug). Automations vuren correct, maar de `switch.turn_off` naar de Tuya-cloud mislukt → afzuiging blijft aan.

**Handmatig te doen (kan niet vanuit CLI):**
1. HA-UI → Instellingen → Apparaten & Diensten → **Tuya** → herconfigureren / opnieuw inloggen (tokens verlopen).
2. **Dubbele Tuya-entry** opruimen (`tuya` + `tuya@toorren.net` — hou die met apparaten).
3. RODRET-batterij vervangen (CR2032; stond op 10% / 1100 mV).

**Config-verbeteringen (doorgevoerd + getest via HA-restart):**
- Nieuwe automation `1771177871264` "Centrale afzuiging uit (knop)": OFF-knop → stekker uit + `timer.cancel`. (OFF-trigger weggehaald uit de "aan"-automation, die zette de afzuiging juist aan.)
- `timer.afzuiging` → `restore: true` in `.storage/timer` (voorheen `false`: bij HA-herstart sprong de timer stil naar idle zonder de afzuiging uit te zetten).
- Backups: `automations.yaml.bak-claude-20260823-212801`, `.storage/timer.bak-claude-20260823-212801`.

**Status:** ⏳ Config-verbeteringen live; hele keten werkt pas weer als Tuya opnieuw is gekoppeld.

### Sessie 2026-05-29 - msmtp agenix secret pad - OPGELOST

**Probleem:** msmtp kon geen mail versturen omdat `/run/agenix/msmtp-password` niet bestond.

**Oorzaak:**
Agenix plaatst secrets in `/run/agenix.d/<generatie>/` en maakt symlinks aan **alleen als je een expliciet `path` opgeeft** in de secret definitie. Zonder `path` wordt de secret wel gedecrypteerd naar `/run/keys/<owner>/<name>`, maar er komt geen symlink op het verwachte pad.

**Oplossing:**
```nix
age.secrets.msmtp-password = {
  file = ../../secrets/msmtp-password.age;
  path = "/run/secrets/msmtp-password";  # expliciet pad vereist!
  owner = "wtoorren";
  mode = "0400";
};
```
En in de config die het secret gebruikt, verwijzen naar dat expliciete pad.

**Les:**
- ✅ Altijd `path = "/run/secrets/<naam>"` opgeven bij `age.secrets` als de secret via een config-bestand wordt gelezen
- ✅ Zonder `path`: secret bestaat alleen in `/run/keys/<owner>/<naam>` (interne agenix opslag)
- ✅ Met `path`: agenix maakt een symlink aan op het opgegeven pad → `/run/keys/<owner>/<naam>`
- ✅ Controleer of secrets bestaan met: `ls -la /run/secrets/` en `ls -la /run/keys/<owner>/`

**Bestanden gewijzigd:**
- `hosts/lobos/mail.nix` - `path` toegevoegd aan secret, `passwordeval` pad bijgewerkt

**Status:** ✅ msmtp verstuurt mail via AWS SES

### Sessie 2026-04-26 - InvoicePlane Docker setup - OPGELOST

**Doel:** InvoicePlane (open source facturatie platform) toevoegen aan malandro via Docker.

**Configuratie:**
- **URL:** `https://invoices.toorren.net`
- **Port:** 8092 (localhost binding)
- **Container:** `funktionslust/invoiceplane:latest`
- **Database:** Bestaande MariaDB op host (localhost)
  - Database: `invoiceplane`
  - Gebruiker: via `secrets/invoiceplane-env.age`
  - Wachtwoord: via `secrets/invoiceplane-env.age`
- **Authenticatie:** Authelia (verplicht)

**Problemen opgelost:**

1. **Port conflict (8084)**
   - Probleem: Port 8084 was al in gebruik door Pi-hole FTL
   - Oplossing: InvoicePlane verplaatst naar port 8092
   - `PORTS.md` bijgewerkt met DocSeal (8090) en InvoicePlane (8092)

2. **Bad Request (400) via nginx**
   - Probleem: Apache gaf "Bad Request" bij requests via nginx
   - Diagnose: Dubbele proxy headers (handmatig + NixOS `recommendedProxySettings`)
   - Oplossing: Handmatige proxy headers verwijderd, NixOS voegt ze automatisch toe

3. **404 Not Found voor /welcome route**
   - Probleem: InvoicePlane routes gaven 404 (bijv. `/welcome`)
   - Diagnose: `.htaccess` bestand ontbrak (bestaat als `htaccess` zonder punt)
   - Root cause: `REMOVE_INDEXPHP=true` env var werkt niet in dit Docker image
   - Oplossing: `ExecStartPost` script dat `htaccess` naar `.htaccess` kopieert bij container start

3. **Module structuur**
   - Van docker-compose naar OCI containers (zoals DocSeal)
   - Alle configuratie via age-encrypted environment file
   - Nginx virtualHost direct in module

**Bestanden gewijzigd:**
- `modules/invoiceplane-docker.nix` - Nieuwe module (OCI containers)
- `hosts/malandro/configuration.nix` - Module import toegevoegd
- `secrets/invoiceplane-env.age` - Database credentials (encrypted)
- `PORTS.md` - DocSeal (8090) en InvoicePlane (8092) toegevoegd

**Belangrijke lessen:**
- ✅ Gebruik OCI containers in plaats van docker-compose voor nieuwe services
- ✅ Check `PORTS.md` voor vrije poorten voordat je een service toevoegt
- ✅ NixOS voegt automatisch proxy headers toe via `recommendedProxySettings` - stel deze niet handmatig in
- ✅ Docker containers kunnen host MariaDB bereiken via `host.docker.internal` (met `--add-host=host.docker.internal:host-gateway`)
- ✅ Nginx reverse proxy betekent NIET dat .htaccess niet nodig is - Apache in de container heeft nog steeds .htaccess nodig voor routing
- ✅ Docker image bugs kunnen workarounds vereisen (zoals ExecStartPost voor .htaccess setup)

**Status:** ✅ InvoicePlane live op https://invoices.toorren.net

### Sessie 2026-04-09 - Suspend/Standby probleem - OPGELOST

**Probleem:** Laptop ging niet correct in standby. WiFi/netwerk adapter werd uitgeschakeld maar de laptop suspendeerde niet volledig.

**Diagnose:**
- Laptop ondersteunt alleen **Modern Standby (S0ix/s2idle)**, GEEN traditionele S3 suspend
- `/sys/power/mem_sleep` toont alleen `[s2idle]`, geen `deep` optie beschikbaar
- S0ix is ontworpen voor Windows en werkt vaak slecht op Linux (AMD laptops)
- Kernel log: `Low-power S0 idle used by default for system suspend`
- NetworkManager wordt correct gestopt maar suspend voltooit niet
- Hardware beperking: BIOS/firmware ondersteunt geen S3 deep sleep

**Oorzaak:**
- Moderne AMD laptop met alleen S0ix ondersteuning (geen S3 in firmware)
- Modern Standby vereist perfecte driver support die vaak ontbreekt op Linux
- Network/wifi driver (ath11k_pci) recovery na suspend niet automatisch

**Oplossing (toegepast):**
Nieuwe module `hosts/lobos/power-management.nix` aangemaakt met:

```nix
# Kernel parameters voor betere S0ix werking
boot.kernelParams = [
  "acpi_osi=Linux"           # Betere ACPI compatibiliteit
  "amd_pstate=active"        # Optimale AMD power management
  "usbcore.autosuspend=-1"   # Voorkom USB wake-up problemen
];

# Services voor network/wifi herstel na suspend
systemd.services.network-resume  # Herstart NetworkManager
systemd.services.wifi-resume     # Herlaadt ath11k_pci driver

# Power management
powerManagement.powertop.enable = true;
```

**Status:**
- [x] `hosts/lobos/power-management.nix` aangemaakt
- [x] Module toegevoegd aan `configuration.nix` imports
- [x] Oude uitgecommentarieerde suspend code verwijderd
- [x] `sudo nixos-rebuild switch --flake .#lobos` succesvol
- [x] Services actief: powertop.service, network-resume.service, wifi-resume.service
- [ ] **Reboot vereist** voor kernel parameter activatie
- [ ] Test suspend na reboot met `systemctl suspend`

**Technische achtergrond:**
- **S3 (deep sleep)**: Traditionele suspend-to-RAM, heel goede Linux support
- **S0ix (s2idle/Modern Standby)**: Nieuwere standaard, ontworpen voor Windows
- Moderne laptops hebben vaak GEEN S3 meer in firmware (alleen S0ix)
- S0ix vereist dat ALLE hardware drivers correct suspend implementeren
- Linux kernel S0ix support is verbeterd maar nog niet perfect voor alle hardware

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

### hosts/lobos/power-management.nix

Bevat alle power management en suspend/resume settings:
- `boot.kernelParams` voor betere S0ix (Modern Standby) werking
- `powerManagement.powertop.enable` voor automatische power optimalisatie
- `systemd.services.network-resume` - herstart NetworkManager na suspend
- `systemd.services.wifi-resume` - herlaadt ath11k_pci driver na suspend
- AMD-specifieke power management (`amd_pstate=active`)
- USB autosuspend workarounds

**Belangrijk:** Laptop ondersteunt ALLEEN S0ix/s2idle (Modern Standby), GEEN S3 deep sleep.


## Systeem Informatie

### Lobos (Desktop)
- **OS:** NixOS 25.11
- **Desktop:** GNOME 49.2 (Wayland)
- **Mutter:** 49.2
- **Display:** Dual monitor (eDP-1 1920x1200 + DVI-I-1 1920x1080)
- **Muziekspeler:** Strawberry

### Malandro (Server)
- **OS:** NixOS 25.11
- **Services:** Nginx, Home Assistant, Grafana, Paperless, Vaultwarden, Gitea, fail2ban

## Useful Commands

### Power Management & Suspend (lobos)
```bash
# Test suspend
systemctl suspend

# Status van suspend services
systemctl status network-resume.service
systemctl status wifi-resume.service
systemctl status powertop.service

# Check suspend logs
journalctl -u systemd-suspend.service -n 50
journalctl -u network-resume.service -n 20
journalctl -u wifi-resume.service -n 20

# Check sleep mode (verwacht: [s2idle] voor deze laptop)
cat /sys/power/mem_sleep

# Check beschikbare suspend states
cat /sys/power/state  # Verwacht: freeze mem disk

# Check kernel power management messages
sudo dmesg | grep -i "suspend\|sleep\|PM:"

# Check wat suspend inhibit (verhindert)
systemd-inhibit --list

# Check powertop statistieken
sudo powertop

# Handmatig wifi driver herladen (bij problemen)
sudo modprobe -r ath11k_pci && sleep 1 && sudo modprobe ath11k_pci

# NetworkManager restart (bij problemen)
sudo systemctl restart NetworkManager.service
```


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
  - `power-management.nix` - Power management & suspend fixes
  - `programs.nix` - Packages (GEBRUIKT)

- **Malandro:** `hosts/malandro/`
  - `configuration.nix` - Main config
  - `programs.nix` - Packages

### Modules
- `modules/fail2ban.nix` - Fail2ban configuratie
- `modules/monitoring/` - Grafana/Prometheus
- `modules/nginx.nix` - Nginx config
- Zie `hosts/malandro/configuration.nix` imports voor volledige lijst
