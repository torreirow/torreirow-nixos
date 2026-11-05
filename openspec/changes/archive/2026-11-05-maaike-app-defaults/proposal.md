## Why

Maaike gebruikt op mpenzi apps die Wouter samen met haar heeft ingericht (Nextcloud, Bitwarden,
ZapZap, Spotify, SMPlayer). Raakt zo'n instelling kwijt of kapot, dan moet Wouter nu via RustDesk
alles opnieuw met haar doorlopen. Hij wil de standaard van een app met één commando kunnen
terugzetten; Maaike voert daarna hooguit een wachtwoord in of scant een QR-code.

## What Changes

- home-manager voor `maaike` als NixOS-module (`modules/maaike-apps.nix`,
  `toorren.maaike.enable`), alleen voor app-config. Geen Plasma-instellingen: die blijven de
  `/etc/xdg`-defaults die zij zelf mag aanpassen.
- **Seeds**: een startbestand per app (Nextcloud, Bitwarden-server, ZapZap, SMPlayer) dat alleen
  wordt neergezet als het ontbreekt. Het blijft een gewoon, schrijfbaar bestand van maaike.
- **herstel-app** `<gebruiker> <app|all>` (systeempakket, via sudo): app stoppen, huidige config
  naar `*.bak-<datum>`, standaard terugzetten. Spotify: de agenix-link opnieuw leggen. Signal:
  alleen uitleg (opnieuw koppelen).
- **Spotify-login** via agenix (`secrets/spotify-maaike.age` → `~maaike/.config/spotify/prefs`),
  alleen als het bestand bestaat; anders een warning.
- **Policies** op mpenzi: Firefox en Chrome installeren Bitwarden en uBlock (Origin / Lite);
  Thunderbird met offline-synchronisatie.
- SMPlayer-startconfig gaat van `systemd.tmpfiles` naar het seed-mechanisme.
- `scripts/vastleggen-app-defaults.sh`: haalt de gouden config van mpenzi op, filtert geheimen
  eruit en toont een diff vóór het schrijven.
- wtoorren-admin: nixvim alleen nog voor `wtoorren` (stond in `sharedModules` en zou anders ook bij
  maaike landen).

## Capabilities

### New Capabilities
- `maaike-app-defaults`: herstelbare app-standaarden voor Maaike op mpenzi.

### Modified Capabilities

## Impact

- Nieuw: `modules/maaike-apps.nix`, `modules/maaike-apps_vmtest.nix`,
  `home/profiles/maaike/{default,seeds}.nix`, `scripts/vastleggen-app-defaults.sh`,
  `docs/maaike-app-defaults.md`.
- Gewijzigd: `flake.nix` (mpenzi-blok, check), `hosts/mpenzi/{configuration,apps}.nix`,
  `modules/wtoorren-admin.nix` (nixvim per gebruiker), `CLAUDE.md`, `CHANGELOG.md`,
  `docs/mpenzi.md`.
- Niet gewijzigd: lobos, malandro, de HM-generatie van `wtoorren` op mpenzi.
