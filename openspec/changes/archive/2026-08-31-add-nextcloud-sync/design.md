# Design — add-nextcloud-sync

## Context

`nextcloudcmd` (uit `pkgs.nextcloud-client`) is een one-shot CLI: hij synct één keer
lokaal ↔ remote en stopt. Een "sync-service" is dus een oneshot
`systemd.user.service` onder een `systemd.user.timer`. Het patroon spiegelt de
bestaande user-services in `home/hyprland/wayle.nix` en de self-contained module-dir
van `home/module/ssh-config_hosts/`.

## Beslissingen

### 1. Credential-mechanisme: `--non-interactive` + EnvironmentFile

Onderzochte opties (spike `nixos-bf5j`):

| Mechanisme | Waar staat het wachtwoord | Verdict |
|------------|---------------------------|---------|
| `-u/-p` op cmdline | in `ps` + nix-store | ✗ lekt |
| `-n` (netrc) | hardcoded `~/.netrc` | ✗ geen custom pad, minder flexibel |
| `--non-interactive` + `$NC_USER`/`$NC_PASSWORD` | EnvironmentFile 0600 | ✓ gekozen |
| `home.file.".../credentials".text` | nix-store (0444) | ✗ **verboden** |

Gekozen: `--non-interactive`, met `EnvironmentFile=` naar een **handmatig** bestand
(`~/.config/nextcloud-sync/credentials`). Reden: geen secret in de nix-store of git,
credential in `~/.config` zoals gewenst, en systemd-native. De EnvironmentFile krijgt
een `-`-prefix (optioneel) zodat een ontbrekend bestand niet vóór `ExecStartPre` faalt
— die geeft dan een nette foutmelding.

Altijd een **Nextcloud app-password** (revocable, scoped), nooit het hoofdwachtwoord.

### 2. Timer: `OnUnitActiveSec` i.p.v. `OnCalendar`

`OnUnitActiveSec=<interval>` triggert het interval ná afloop van de vorige run, zodat
een trage sync niet overlapt met de volgende. `OnActiveSec=2min` voor een eerste run
kort na login. Bewust géén `Persistent`/`OnCalendar`: voor een continu-draaiende
desktop is "elke N minuten sinds de vorige run" het juiste model.

### 3. Module-API: `services.nextcloud-sync` met `syncs.<naam>`

`syncs` is een `attrsOf submodule`, zodat meerdere sync-paren (elk eigen
service+timer) mogelijk zijn. Per paar: `serverUrl`, `localPath`, `remotePath` (`/`),
`interval` (`10min`), `excludeFile`, `trust`, `extraArgs`.

### 4. Path-handling

Een leidende `~/` in `localPath`/`excludeFile` wordt bij eval geëxpandeerd naar
`config.home.homeDirectory` (systemd expandeert `~` niet in ExecStart-argumenten).
`ExecStartPre` doet `mkdir -p` van de lokale map + een per-sync `--confdir` state-dir,
zodat de headless sync zijn eigen journal/config bijhoudt en niet botst met een
eventuele GUI-client.

## Non-goals

- Geen live/continue sync (dat kan `nextcloudcmd` niet; timer-polling volstaat).
- Geen agenix/homeage-integratie (bewust: credential blijft handmatig, buiten de repo).
- Geen automatische activering met echte credentials — `enable` blijft `false` tot de
  gebruiker het credentials-bestand aanmaakt en de module inschakelt.

## Verificatie

- `nix eval` van de default (`enable = false`) → module evalueert schoon.
- `extendModules` met twee sync-paren → correcte `ExecStart` (path-normalisatie,
  `--path`, `--trust`, `--confdir`, positionele volgorde), `EnvironmentFile`-prefix en
  timer-waarden.
- `nix build` van de volledige `activationPackage` → bouwt end-to-end.
