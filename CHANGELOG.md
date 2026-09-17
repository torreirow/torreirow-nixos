# Changelog

All notable changes to this NixOS configuration.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## NEXT VERSION

### Added
- **bobadela1 ochtend-wake** (`modules/wake-bobadela1/`, malandro): malandro wekt bobadela1 elke ochtend 09:00 automatisch via Wake-on-LAN — het complement van de bestaande 23:00-shutdown, zodat Nextcloud 's ochtends vanzelf beschikbaar is (voorheen handwerk).
  - Doorzettend: 30 minuten lang proberen met een WoL-burst elke 5 minuten (`systemd`-timer, `Persistent=true`, dagelijks incl. weekend).
  - Succescriterium is **Nextcloud zelf**, niet alleen ping: pas klaar als `status.php` HTTP 200 geeft met `installed:true` en `maintenance:false`. Idempotent — al gezond → geen packet.
  - **Signal-melding bij falen** met onderscheid: host kwam niet op (geen ping) versus host op maar Nextcloud niet gezond. Best-effort via de bestaande signal-cli REST API.
  - Eén gedeelde bron: de root-service gebruikt het store-pad; `wake-bobadela1` staat ook in `~/bin` (home-manager) voor handmatig wekken.
- **Lynis-beveiligingsbaseline voor lobos** (`hosts/lobos/security-hardening.nix`): hardening-index van 64 naar 72.
  - `nftables` toegevoegd aan de systeempakketten, waardoor audittooling de al draaiende firewall weer detecteert (was een vals negatief: NixOS bouwt iptables als kernelmodule en het `nft`-binary ontbrak in PATH). Het filtergedrag is ongewijzigd.
  - `security.audit.rules` met gerichte watches op `/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/sudoers` en op het laden van kernelmodules. De audit-daemon draaide voorheen met een lege regelset: wel overhead, geen opbrengst.
  - Twaalf gehardende kernelparameters via `boot.kernel.sysctl` (bestandsbescherming, suid-coredumps, kernel-pointer-restrictie, BPF-JIT-hardening, ICMP-redirects en martian-logging). Vijf parameters uit het scanprofiel zijn bewust niet gezet en staan met reden gedocumenteerd in de module -- twee ervan zouden de WiFi-resume-hack en het Docker-containernetwerk breken.
- **tmux notepad-shortcut**: Nieuwe tmux-binding `prefix + N` toggelt tussen de smug `notepad`-werkomgeving (vim/LinnyStart + git-sync + hugo op poort 1314) en de hoofdsessie `main`. Zit je in notepad → terug naar `main`; zit je elders → naar notepad (idempotent gestart via `smug start notepad --detach` als de sessie nog niet draait). Gebruikt `switch-client` (blijvende sessie) i.p.v. een popup, en richt zich op de echte sessienaam `TorrLinny` die `notepad.yml` aanmaakt.
- **Nextcloud op JuiceFS/S3** (`nxc.toorren.net`, host bobadela1): de Nextcloud AIO-datadir draait nu op een JuiceFS-filesystem met de bestandsdata in AWS S3 (`s3://wto-s3-bucket/juicefs/`) en de metadata in een lokale PostgreSQL 16. JuiceFS levert echte POSIX-semantiek (atomic rename, flock) — veilig als datadir, anders dan naïef S3-via-FUSE.
  - **Client-side encryptie** (`aes256gcm-rsa`): alle data staat versleuteld in S3 (geverifieerd ciphertext).
  - **Metadata-DR via PostgreSQL logical replication**: bobadela1 (publisher) → malandro (subscriber, db `juicefs_meta_replica`), live gesynct. Automatisch mee in de rustic-backup via `pg_dumpall`, plus JuiceFS' eigen `--backup-meta` uur-dump naar S3.
  - Eigen IAM-user (`juicefs-nextcloud`) write-scoped op de `juicefs/`-prefix; secrets via agenix (`secrets/juicefs-*.age`). systemd-mount met boot-ordering vóór de AIO-containers (geen split-brain).
  - Migratie van 4,2 GiB byte-perfect (`files:scan`: 0 verschillen). Runbook + provisioning in `hosts/bobadela1/`.
- **S3-bucket dichtgezet**: Block Public Access aangezet op `wto-s3-bucket` — persoonlijke data en backups zijn niet langer anoniem publiek leesbaar (eerdere `DirectReads`-policy stond bucket-breed open).
- **Torrlinny notities-web** (`linny.toorren.net`): de privé Hugo-repo `torreirow/torrlinny` wordt ontsloten als een strakke, doorzoekbare statische site achter Authelia, die automatisch herbouwt bij een push naar `main`.
  - Gebouwd met de gedeelde **[linny-web-theme](https://github.com/torreirow/linny-web-theme)** Hugo-module (bundelt geekdoc + de Linny-layouts: taxonomie-zijbalk, Created/Updated-datums, overzichtspagina's). Torrlinny's `hugo-web.yaml` importeert de module; de build haalt 'm met `hugo mod get` (Go in de service-PATH). Géén eigen overlay meer op malandro.
  - **Full-text zoeken** (geekdoc, ingebouwd) + taxonomie-navigatie (customer/project/type/tags) + twee paginated overzichten (op titel/datum) + per-notitie Created (`crdate`) + Updated (git `.Lastmod`).
  - **fence.py**: box-drawing CLI-output (bv. `aws … --output table`) wordt in een ```text-fence gewikkeld (in-place op de wegwerp-checkout, `.git` intact voor `enableGitInfo`).
  - Runtime build-service (git → `hugo mod get` → fence → `hugo --minify` → **atomic symlink-swap**, **keep-last-good**) met een timer + change-detectie; géén `nixos-rebuild` per notitie-wijziging.
  - Read-only SSH deploy key via agenix (`secrets/torrlinny-deploy-key.age`); nginx-vhost achter Authelia.
- **linny-web-theme** (nieuwe repo `github.com/torreirow/linny-web-theme`, publiek, Hugo-Module): de torrlinny-web-view als herbruikbare Hugo-theme voor álle Linny-notebooks. Vendort geekdoc's prebuilt release (MIT) + de Linny-layouts/overzichtspagina's; één `hugo mod get`. Opgenomen in `linden-project/linny-notebook-template` (PR) zodat elk nieuw notebook de web-view out-of-the-box heeft.
- **Nextcloud sync (home-manager)**: Nieuwe module `services.nextcloud-sync` (`home/module/nextcloud-sync/`) om per user een headless Nextcloud-sync in te regelen met `nextcloudcmd`. Elk sync-paar onder `syncs.<naam>` levert een oneshot `systemd.user.service` + `.timer`. Geïmporteerd in `wtoorren@linuxdesktop`; standaard uit (`enable = false`).
  - Auth via `nextcloudcmd --non-interactive` dat `$NC_USER`/`$NC_PASSWORD` uit een handmatig EnvironmentFile (`~/.config/nextcloud-sync/credentials`, 0600) leest — nooit in de nix-store of git
  - Timer-cadans via `OnUnitActiveSec` (default 10 min, geen overlap) + eerste run 2 min na login
  - Opties per sync: `serverUrl`, `localPath` (`~/` wordt geëxpandeerd), `remotePath` (`--path`), `interval`, `excludeFile`, `trust`, `extraArgs`
  - Activeren vereist eenmalig een handmatig credentials-bestand met een Nextcloud **app-password**
- **Wayle clipboard dropdown**: Clipboard history icoon in de wayle-bar rechtsboven, naast planify. Klikken opent een native GTK4 dropdown met alle entries van `cliphist`. Klik op een entry → gekopieerd naar clipboard en dropdown sluit. Vervangt niet de `Ctrl+Super+C` fuzzel picker — beide bestaan naast elkaar.
  - Nieuw Rust/Relm4 component in de wayle fork (`crates/wayle-shell/src/shell/bar/dropdowns/clipboard/`)
  - Entries worden geladen via `cliphist list` op popover open-event (geen polling)
  - Selectie via `cliphist decode | wl-copy` zonder shell-escaping problemen
  - `edit-copy-symbolic` icoon in de bar layout
- **Hyprland font scaling**: X11/XWayland apps tonen nu dezelfde tekstgrootte als Wayland apps via `Xft.dpi = 120` (96 × monitor scale 1.25). Daarnaast zijn er drie keybindings voor runtime tekstgrootte-aanpassing via `gsettings text-scaling-factor` met visuele feedback:
  - `Super+Ctrl+Shift+=` — tekst groter (+0.1, max 2.0)
  - `Super+Ctrl+Shift+-` — tekst kleiner (-0.1, min 0.8)
  - `Super+Ctrl+Shift+0` — reset naar standaard (1.0)
- **Hyprland workspace-monitor binding**: Workspaces 1-10 zijn persistent en worden dynamisch aan de externe monitor gekoppeld. WS 1, 4, 6, 8, 10 landen op het externe scherm; WS 2, 3, 5, 7, 9 op de laptop. Werkt automatisch thuis én op kantoor ongeacht de poortnaam (HDMI-A-1, DP-10, etc.) via een `workspace-binder` service die monitor-events afluistert. Apps Slack/Teams → WS 3, Firefox → WS 4.
- **Wayle weather `location-name` override**: Voeg `location-name` config optie toe aan de wayle weather module via een lokale fork. Hiermee is het mogelijk coördinaten te gebruiken voor accurate weerdata terwijl een leesbare naam in de dropdown header wordt getoond (bijv. `location-name = "Ermelo"`). Oplossing voor het probleem dat coördinaten een lege/incorrecte naam gaven, en een stadsnaam de verkeerde stad opleverde (Open-Meteo geocoding geeft de Zuidafrikaanse Ermelo vóór de Nederlandse).
  - Nix overlay toegevoegd (`overlays/wayle.nix`) voor lokale wayle fork
  - `location-name` veld toegevoegd aan `WeatherConfig` schema in de fork
  - Weather dropdown header toont nu geconfigureerde naam i.p.v. API-resultaat

### Removed
- **`modules/hardening.nix`**: werd nergens geimporteerd en was bovendien onbouwbaar geworden -- `chkrootkit` is uit nixpkgs verwijderd ("unmaintained and archived upstream and didn't even work on NixOS") en `rkhunter` bestaat er evenmin nog. Er is bewust geen malware-scanner voor in de plaats gekomen.

### Fixed
- **Dode wachtwoordbeleid-configuratie in `hosts/lobos/configuration.nix`**: een uitgecommentarieerd `security.pam.loginLimits`-blok met `PASS_MAX_DAYS`/`PASS_MIN_DAYS` verwijderd. Die optie schrijft naar `limits.conf` (ulimits) en nooit naar `login.defs`, dus het zou ook actief niets gedaan hebben.
- **Wayle weather crash bij Refresh**: `trigger_refresh()` in de wayle fork gebruikte `LocationQuery::city()` ongeacht de locatie-invoer, waardoor coördinaten (`"52.2983,5.6222"`) werden doorgegeven aan de Open-Meteo geocoding API als plaatsnaam — resulterend in `location not found`. De fix past dezelfde coördinatendetectie toe (`split_once(',')` → `parse::<f64>()`) als de rest van de codebase.
- **SubtitleEdit Ctrl-X/Ctrl-V clipboard**: `autocutsel` toegevoegd aan Hyprland exec-once om de X11 clipboard actief te houden. SubtitleEdit draait via Mono/XWayland en verliest de clipboard selection zodra de muisknop wordt losgelaten; `autocutsel` synchroniseert de X11 PRIMARY selection naar de clipboard continu.
