# mpenzi: laptop van Maaike

NixOS-laptop voor Maaike, die van Windows overstapt. Kaal host-blok in de flake (geen Hyprland,
geen extraPkgs, geen home-manager). OpenSpec-change: `mpenzi-laptop` (gearchiveerd), epic
`nixos-54um`.

## Overzicht

| Onderwerp     | Keuze                                                                        |
|---------------|------------------------------------------------------------------------------|
| Basis         | NixOS 26.05, Plasma 6 + SDDM (Wayland), systemd-boot, LUKS root + swap       |
| Taal          | `nl_NL.UTF-8`, `Europe/Amsterdam`, toetsenbord `us` variant `intl`           |
| Gebruikers    | `maaike` (geen wheel), `wtoorren` (wheel + ssh-key)                          |
| Beheer        | ssh alleen met sleutel, geen root; updates handmatig vanaf lobos             |
| Remote access | Nebula `toorren` (10.77.0.3) + RustDesk direct IP op poort 21118             |
| Apps          | Firefox, Chrome, OnlyOffice, Nextcloud, Thunderbird, Zoom, Bitwarden,        |
|               | Spotify, Signal, Audacity, ZapZap (WhatsApp), SMPlayer (standaard), VLC      |
| Webapps       | Canva en Jitsi Meet als Chrome `--app`-venster                               |
| Zelf          | Discover + Flathub                                                           |

Bestanden: `hosts/mpenzi/{configuration,hardware-configuration,plasma,apps,rustdesk}.nix`,
`modules/nebula.nix`, test `modules/nebula_vmtest.nix`.

## Updaten (vanaf lobos)

```bash
nixos-rebuild switch --flake .#mpenzi --target-host wtoorren@mpenzi --sudo --ask-sudo-password
```

- `wtoorren@mpenzi` werkt thuis via `mpenzi.local` (avahi), onderweg via `10.77.0.3` (Nebula).
- `@wheel` is trusted user op mpenzi; anders weigert de nix-daemon de ongesigneerde closure.
- Geen `autoUpgrade`: Maaike's laptop verandert alleen als Wouter deployt.

## Plasma-defaults

Staan in `/etc/xdg` (`kdeglobals`, `kglobalshortcutsrc`). KConfig leest die als systeemlaag ónder
`~/.config`, dus wat Maaike zelf instelt wint. Daarom bewust geen plasma-manager.

| Toets       | Actie                              |
|-------------|------------------------------------|
| Win+E       | Dolphin                            |
| Win+L       | Vergrendelen                       |
| Win+Shift+S | Schermafbeelding van een rechthoek |

Verder: dubbelklik om te openen, Firefox als standaardbrowser. Werkt een default niet bij een
bestaand account, dan heeft dat account al een eigen waarde in `~/.config/<bestand>`.

## Nebula-mesh

| Host     | Nebula-IP | Rol                       | Inbound (naast ICMP)              |
|----------|-----------|---------------------------|-----------------------------------|
| malandro | 10.77.0.1 | lighthouse + relay (4242) | geen                              |
| lobos    | 10.77.0.2 | node                      | geen                              |
| mpenzi   | 10.77.0.3 | node                      | tcp 22 en 21118, alleen van lobos |

- Het beleid staat in de `hosts`-tabel bovenin `modules/nebula.nix`. Een host erbij: regel
  toevoegen, cert maken, module importeren.
- Lighthouse-adressen: eerst `192.168.2.52:4242` (thuis, geen hairpin), daarna
  `wg.toorren.net:4242`.
- De host-firewall vertrouwt `nebula.toorren`; de Nebula-firewall is de enige poortwachter. Op
  wifi/LAN gaat niets extra open.
- **Zonder certificaten staat Nebula uit.** De module kijkt of `secrets/nebula-ca.crt.age` en
  `secrets/nebula-<host>.{crt,key}.age` bestaan. Ontbreken ze, dan bouwt de host gewoon en meldt
  de evaluatie `toorren.nebula: ... ontbreken`.
- Test: `nix build .#checks.x86_64-linux.nebula -L` (drie VM's met wegwerp-certs: lobos mag wel
  22/21118 op mpenzi, malandro niet, 21118 dicht op de underlay).

### Certificaten maken (handmatig, op lobos)

```bash
nebula-cert ca -name toorren -duration 87600h       # CA-sleutel naar Vaultwarden, NIET de repo
nebula-cert sign -name malandro -ip 10.77.0.1/24
nebula-cert sign -name lobos    -ip 10.77.0.2/24
nebula-cert sign -name mpenzi   -ip 10.77.0.3/24
```

Daarna per bestand versleutelen met ragenx (`ragenx -e secrets/nebula-<host>.crt.age`, inhoud via
stdin) volgens de recipients in `secrets/secrets.nix`. Voor mpenzi eerst de host-key toevoegen en
de uitgecommentarieerde regels aanzetten. De `.age`-bestanden moeten in git staan, anders ziet de
flake ze niet.

`home/RUNME.sh new_nebula_node` gaat uit van een CA-sleutel in de repo
(`secrets/nebula-ca.key.age`). Dat is hier bewust niet zo; gebruik het script niet voor deze mesh.

Router: UDP 4242 doorsturen naar malandro (192.168.2.52).

## RustDesk

- mpenzi draait `rustdesk --service` als systeemservice (zoals het upstream .deb-pakket). Onder
  Wayland (de Plasma-sessie van Maaike) doet die niets: het log toont `cannot open display:` en
  poort 21118 luistert niet. Getest 2026-11-04.
- Werkwijze: Maaike opent RustDesk zelf als ze hulp wil en keurt "scherm delen" goed. Zolang het
  venster open is, luistert RustDesk op 21118 (alleen bereikbaar via Nebula, dicht op het LAN).
  Bewust geen autostart.
- Bij de start zet de service `direct-server = 'Y'` in `/root/.config/rustdesk/RustDesk2.toml`,
  alleen als die optie er nog niet staat.
- Verbinden vanaf lobos: RustDesk openen, `10.77.0.3` als ID invullen.

**Na de eerste deploy controleren** (de seed is niet op hardware getest): open RustDesk op mpenzi →
Instellingen → Beveiliging → "Directe IP-toegang inschakelen" moet aan staan met poort 21118. Staat
hij uit, zet hem daar aan; de GUI-keuze blijft staan.

Open punt: de publieke ID-server van RustDesk staat nog aan. Verbinden op ID (met wachtwoord) kan
dus nog. Uitzetten kan met een eigen of dummy rendezvous-server; dat valt buiten deze change.

## Waarom geen jitsi-meet-electron

In nixpkgs 26.05 hangt dat pakket aan Electron 41, dat EOL is en als insecure staat gemarkeerd. Een
insecure pakket op de laptop van een beginnende gebruiker willen we niet. Jitsi werkt in Chrome net
zo goed, dus het is een webapp geworden.

## Handmatige stappen

Bean `nixos-w4ci`: eerste deploy, host-key, wachtwoorden, Nebula-CA/certs, router, RustDesk-check,
sysadmin weghalen.
