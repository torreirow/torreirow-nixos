# Claude Code Werkdocument - torreirow-nixos

**Laatst bijgewerkt:** 2026-10-09

> Dit bestand wordt elke sessie volledig geladen en blijft daarom bewust kort. De details per
> onderwerp staan in `docs/` en worden **on-demand** gelezen zodra je over dat onderwerp nadenkt
> (zie de index hieronder). Bij nieuw substantieel sessiewerk: schrijf de uitwerking in het
> passende `docs/`-bestand (of maak een nieuw bestand + indexregel), niet in dit bestand.

## Contextbestanden (lees on-demand)

- **Vragen over USB dongle, Zigbee dongle, DSMR adapter, `/dev/zigbee`, `/dev/dsmr` of ttyUSB-poorten die verwisselen** → lees `docs/usb-dongles.md`
- **Vragen over Magister, de agenda-sync, het token/refresh-token, `magister-sync.service`, `token.json`, iCal-feeds op `agenda.toorren.net` of opnieuw inloggen** → lees `docs/magister.md`
- **Vragen over Torrlinny, `linny.toorren.net`, de notities-web, `torrlinny-build.service`, de Hugo/Pagefind-overlay of de deploy key** → lees `docs/torrlinny.md`
- **Vragen over linny-mcp, `linny-mcp.toorren.net`, het notitieboek als MCP-server voor Claude, de publieke schrijfroute/`publicWrite`, `status: agent-draft`/quarantine, de bearer-tokens of waarom er twee corpus-werkmappen zijn** → lees `docs/linny-mcp.md`
- **Vragen over de Vaultwarden restore-test, `vaultwarden-restoretest.sh`, `--rbw`/`--destroy`, de wegwerp-container op poort 8099 of de rbw-crypto-test** → lees `docs/vaultwarden-restore-test.md`
- **Vragen over de reMarkable, `remarkable-sync`, `10.11.99.1`, de USB-webinterface van xochitl, `.rm`-bestanden, `error -71` op USB of PDF-export naar Nextcloud** → lees `docs/remarkable.md`
- **Vragen over het opnemen van een meeting, `meetrec`, `~/Meetings`, de twee sporen (`anderen`/`ik`), `stream.capture.sink`, de Opus-encoding of het whisper-transcript** → lees `home/module/meeting-record/README.md`
- **Vragen over `staleness-monitor`, waarom de Nextcloud-sync géén melding per mislukking meer geeft, de twee drempels (24u/48u), het stempelbestand `last-success-*` of `notify-signal.sendCommand`** → lees `home/module/staleness-monitor/README.md`
- **Vragen over de HA-recorder, welke entities wel/niet bewaard worden, retentie/`purge_keep_days` of neerslag/plantwater-opslag** → lees `docs/homeassistant-data-retention.md`
- **Vragen over de HA→Prometheus-export, `include_domains`, metricnamen of waarom een entity niet in Prometheus staat** → lees `docs/homeassistant-prometheus-setup.md`
- **Vragen over opstarten na een stroomstoring, de volgorde van diensten of handmatig herstel** → lees `docs/na-stroomstoring.md`
- **Vragen over hyprlock, de vingerafdruk-unlock op lobos, `fprintAuth`, de claim-retry-patch (PR #1049) of de roterende lock-teksten** → lees `docs/hyprlock-fingerprint.md`
- **Vragen over IT-Tools, `ittools.toorren.net`, het eigen sharevb-fork image, container-poort 8085 of figlet-fonts** → lees `docs/ittools.md`
- **Vragen over Authelia RBAC, `access_control`, de groepen (monitoring/network/operations/office/linny), de gescheiden accounts (wouteradmin/wouter/wouteruser) of Grafana-via-OIDC (de vier 'Viewer i.p.v. Admin'-valkuilen)** → lees `docs/authelia-rbac.md`
- **Vragen over de neerslag-indicator, het Temperatuur/Vocht-dashboard, Buienradar in HA, het dauwpunt of `sensor.neerslag_indicator`** → lees `docs/neerslag-indicator.md`
- **Vragen over lynis-hardening op lobos, de hardening-index, `security-hardening.nix`, auditregels of sysctls** → lees `docs/lynis-hardening-lobos.md`
- **Vragen over trage/vastlopende sessies tijdens een `nix build`/`nixos-rebuild`, de nix-daemon-throttling (SCHED_IDLE), `max-jobs`/`cores` of de eval-fase-alias** → lees `docs/nix-build-throttling.md`
- **Vragen over het agenda-wandpaneel, de HA-kiosk, kiosk-mode.js, de read-only user `paneel` of het `/calendar`-dashboard** → lees `docs/agenda-wandpaneel.md`
- **Vragen over de rustic S3-backup, `rustic-backup.service/.timer`, de pg/mariadb/vaultwarden-dumps, het repo-wachtwoord of de backup-manifest** → lees `docs/rustic-s3-backup.md`
- **Vragen over HA-automations die buiten de repo leven (aircraft-monitor/`/aircraft`, geurhal/WC, centrale afzuiging), timer `restore: true` of de `.storage` stop-edit-start-werkwijze** → lees `docs/ha-automations.md`
- **Vragen over msmtp, mail versturen via SES, of waarom een agenix-secret niet op `/run/secrets/<naam>` verschijnt (`path` vereist)** → lees `docs/msmtp-agenix.md`
- **Vragen over InvoicePlane, `invoices.toorren.net`, de OCI-container op poort 8092 of de `.htaccess`-workaround** → lees `docs/invoiceplane.md`
- **Vragen over suspend/standby op lobos, S0ix/s2idle vs S3, `power-management.nix`, de resume-services of de ath11k_pci-wifi-hack** → lees `docs/power-management-lobos.md`
- **Vragen over Qt/Wayland/GNOME op lobos, `QT_QPA_PLATFORM`, Electron op Wayland, `gnome-wayland.nix`, de Super+L-keybinding, MuseScore of Strawberry (muziekspeler/radiostreams)** → lees `docs/qt-wayland-gnome.md`
- **Vragen over fail2ban op malandro, `modules/fail2ban.nix`, de jails of de NixOS 25.11-opties die niet op top-level bestaan** → lees `docs/fail2ban.md`

## Meetprincipe bij periodiek werk met geplande downtime

Meet het **resultaat**, niet de storing. Een melding per mislukte run vraagt om het onderscheiden
van oorzaken (geen netwerk / dienst uit / echt stuk) en is daardoor duur en broos. De vraag "is dit
werk de afgelopen N uur überhaupt geslaagd?" is zonder enige oorzaakkennis te beantwoorden.

Concreet bewijs waarom dat onderscheid duur is: op 2026-09-17 faalde de Nextcloud-sync twee keer
kort na elkaar met twee verschillende oorzaken — een DNS-fout omdat lobos zelf nog geen netwerk
had, en een `502 Bad Gateway` omdat de nginx vóór Nextcloud wél draaide maar de backend niet. Let
op dat tweede geval: **een reverse proxy antwoordt ook als de dienst erachter plat ligt**, dus een
poort- of ping-probe zegt ten onrechte "beschikbaar". Toets op inhoud (`status.php` → `installed`,
`maintenance`), niet op een statuscode.

## Systeem Informatie

### Lobos (ThinkPad, AMD Ryzen 7 PRO 7840U)
- **OS:** NixOS 25.11
- **Desktop:** Hyprland (voorheen GNOME 49.2 Wayland — zie `docs/qt-wayland-gnome.md` voor die historie)
- **Display:** Dual monitor (eDP-1 1920x1200 + DVI-I-1 1920x1080)
- **Muziekspeler:** Strawberry
- **Suspend:** ALLEEN S0ix/s2idle (geen S3 deep sleep) — zie `docs/power-management-lobos.md`

### Malandro (Server)
- **OS:** NixOS 25.11
- **Services:** Nginx, Home Assistant, Grafana, Paperless, Vaultwarden, Gitea, Authelia, fail2ban

## Veelgebruikte commando's

Per-onderwerp commando-cheatsheets staan in de bijbehorende `docs/`-bestanden (power, fail2ban,
Strawberry, Qt/Wayland). De basis:

```bash
# NixOS rebuild — lobos
sudo nixos-rebuild switch --flake .#lobos
# NixOS rebuild — malandro (remote)
sudo nixos-rebuild switch --flake .#malandro
# Debug / dry-run
sudo nixos-rebuild switch --flake .#malandro --show-trace
sudo nixos-rebuild dry-build --flake .#malandro
# Home-manager (lobos)
home-manager switch --flake .#wtoorren@linuxdesktop --extra-experimental-features nix-command -b backup-$(date +%s) --impure

# Git
git status
git diff --staged
git log --oneline -10
```

## File Locations

### Config bestanden
- **Lobos:** `hosts/lobos/`
  - `configuration.nix` - Main config
  - `gnome-wayland.nix` - GNOME/Wayland settings (historie, zie `docs/qt-wayland-gnome.md`)
  - `power-management.nix` - Power management & suspend fixes (zie `docs/power-management-lobos.md`)
  - `programs.nix` - Packages (GEBRUIKT)
- **Malandro:** `hosts/malandro/`
  - `configuration.nix` - Main config
  - `programs.nix` - Packages

### Modules
- `modules/fail2ban.nix` - Fail2ban configuratie (zie `docs/fail2ban.md`)
- `modules/monitoring/` - Grafana/Prometheus
- `modules/nginx.nix` - Nginx config
- Zie `hosts/malandro/configuration.nix` imports voor volledige lijst
