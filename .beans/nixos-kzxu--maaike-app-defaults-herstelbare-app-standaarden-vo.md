---
# nixos-kzxu
title: 'maaike-app-defaults: herstelbare app-standaarden voor Maaike op mpenzi'
status: completed
type: epic
priority: normal
created_at: 2026-11-04T21:10:32Z
updated_at: 2026-11-05T09:15:47Z
---

App-standaarden voor **maaike** op mpenzi: Wouter moet standaardinstellingen van haar apps makkelijk
kunnen terugzetten; Maaike voert daarna hooguit eenmalig een wachtwoord in (of scant een QR-code).
Uitgewerkt op 2026-11-04. Maak bij uitvoering een OpenSpec change (voorstel: `maaike-app-defaults`).

## Besloten

| Onderwerp     | Keuze                                                                                  |
|---------------|----------------------------------------------------------------------------------------|
| Vorm          | home-manager als NixOS-module voor `maaike` (zelfde route als wtoorren-admin), profiel `home/profiles/maaike/`. ALLEEN app-config; GEEN plasma-manager/Plasma-instellingen (die blijven `/etc/xdg`-defaults die zij mag aanpassen) |
| Drie mechanismen | (1) **policy**: altijd juist, systeemniveau; (2) **agenix-secret met `path`**: zoals lobos `spotifywto`, herstel = deploy; (3) **seed + herstel**: startbestand alleen als het ontbreekt, plus `herstel-app` |
| Firefox       | `programs.firefox.policies`: extensies Bitwarden + uBlock Origin (force_installed, zoals `hosts/lobos/programs.nix`) |
| Chrome        | `programs.chromium.extraOpts` (geldt ook voor Google Chrome): zelfde extensies via ExtensionInstallForcelist |
| Thunderbird   | `programs.thunderbird.policies`: offline/synchronisatie aan; Gmail-OAuth blijft handwerk |
| Spotify       | agenix-secret `secrets/spotify-maaike.age` → `/home/maaike/.config/spotify/prefs` (owner maaike, 0600), recipients `users ++ [ mpenzi ]`. Exact het lobos-patroon (`hosts/lobos/lobos-secrets.nix`, `spotifywto`). Het .age-bestand maakt Wouter (handmatig) |
| Nextcloud     | **GUI-client** (`nextcloud-client`, autostart). Seed `~/.config/Nextcloud/nextcloud.cfg`: server `https://nxc.toorren.net`, gebruiker `mtoorren`, map `~/Nextcloud` ↔ `/`, launchOnStartup. Login via browser (Login Flow) |
| Bitwarden     | Desktop-app: seed met server `https://vw.toorren.net` (en e-mail als optie, nu leeg). Master-wachtwoord blijft per keer nodig |
| ZapZap, Signal | Seed van niet-geheime instellingen (systeemvak, meldingen) uit de gouden config. Koppelen = QR-code scannen met haar telefoon |
| Herstellen    | Script `herstel-app <gebruiker> <app\|all>` (systeempakket, via sudo): app stoppen, huidige config naar `*.bak-<datum>`, standaard uit de Nix-store terugzetten. Voor Spotify: agenix-secret opnieuw activeren. Wouter draait: `ssh wtoorren@10.77.0.3 sudo herstel-app maaike nextcloud` |
| Gouden config | Standaarden voor Spotify-instellingen/ZapZap/Signal worden niet geraden: Wouter richt de apps één keer in met Maaike (RustDesk); een script `vastleggen-app-defaults` kopieert de niet-geheime bestanden (tokens eruit gefilterd) naar `home/profiles/maaike/defaults/` |

## Grenzen voor de agent

- GEEN `nixos-rebuild switch`; alleen build/eval/VM-test.
- GEEN .age-bestanden maken (Spotify-prefs bevatten een login-token); wel de `secrets.nix`-regel en
  de config die het bestand optioneel maakt (`builtins.pathExists`, zoals `modules/nebula.nix`).
- Geen tokens, wachtwoorden of e-mailadressen van Maaike in de repo.
- Bestanden die een app zelf schrijft NIET als HM-symlink beheren (read-only breekt de app).
- Beans met tag `handmatig` niet uitvoeren.

## Acceptatiecriteria

- mpenzi bouwt met het profiel; `maaike` heeft HM, zonder plasma-manager.
- Zonder `spotify-maaike.age` bouwt mpenzi gewoon (warning), met het bestand landt het op het juiste pad met owner maaike.
- VM-test: bij eerste login ontstaan de seeds (nextcloud.cfg met `nxc.toorren.net` en `mtoorren`,
  Bitwarden-server); een tweede login overschrijft een gewijzigd bestand NIET; `herstel-app <user> nextcloud`
  zet de standaard terug en laat een `.bak-*` achter.
- Firefox- en Chrome-policies bevatten de Bitwarden- en uBlock-extensies.
- Docs: `docs/maaike-app-defaults.md` (per app: wat is standaard, hoe herstellen, wat moet Maaike daarna doen) + indexregel in `CLAUDE.md`.


## Summary of Changes

modules/maaike-apps.nix (toorren.maaike): home-manager voor maaike met seeds (Nextcloud, Bitwarden, ZapZap, SMPlayer), herstel-app, Spotify-login via agenix; Firefox/Chrome/Thunderbird-policies in hosts/mpenzi/apps.nix; scripts/vastleggen-app-defaults.sh; VM-test checks.x86_64-linux.maaike-apps; docs/maaike-app-defaults.md. OpenSpec 2026-11-05-maaike-app-defaults. Herstel van Nextcloud op mpenzi getest.
