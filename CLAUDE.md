# Claude Code Werkdocument - torreirow-nixos

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
```

## Systeem Informatie

### Lobos (Desktop)
- **OS:** NixOS 25.11
- **Desktop:** GNOME (Wayland)
- **Display:** Dual monitor (eDP-1 1920x1200 + DVI-I-1 1920x1080)
- **Muziekspeler:** Strawberry (was Clementine)

### Malandro (Server)
- **OS:** NixOS 25.11
- **Services:** Nginx, Home Assistant, Grafana, Paperless, Vaultwarden, Gitea, etc.
- **Security:** Fail2ban (nu geconfigureerd), Authelia
- **Storage:** /data/external (ext4, nofail mount)

## Volgende Sessie TODO

1. [ ] Lobos: `sudo nixos-rebuild switch` uitvoeren voor Strawberry
2. [ ] Malandro: `sudo nixos-rebuild switch --flake .#malandro` voor fail2ban
3. [ ] Fail2ban testen en logs checken
4. [ ] Overwegen: programs.wouter terugdraaien naar originele staat (niet gebruikt)
5. [ ] Git commit maken voor Strawberry migratie en fail2ban configuratie

## Bekende Issues

- ❌ Geen - alles werkt naar verwachting

## Resources

- NixOS Options Search: https://search.nixos.org/options?channel=25.11
- Fail2ban Wiki: https://github.com/fail2ban/fail2ban/wiki
- Strawberry Music Player: https://www.strawberrymusicplayer.org/
