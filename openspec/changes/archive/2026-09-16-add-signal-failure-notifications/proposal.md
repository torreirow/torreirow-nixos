## Why

Op **lobos** faalde `nextcloud-sync-docs` van **9 tot 16 september 2026** onafgebroken: 419
mislukte runs, nul geslaagde. Niemand merkte het, en dat had twee oorzaken die elkaar versterkten.

**1. De unit zweeg.** `home/module/nextcloud-sync/` gaf `--silent` hardgecodeerd mee aan
`nextcloudcmd`. Met die vlag schrijft de client niets naar stdout, ook niet bij een fout. In de
journal stond dus uitsluitend:

```
nextcloud-sync-docs.service: Main process exited, code=exited, status=1/FAILURE
Failed to start Nextcloud sync (docs).
```

Geen reden, geen aanwijzing. De werkelijke oorzaak — een verlopen wachtwoord, en daarna HTTP 429
brute-force-throttling — werd pas zichtbaar door het commando handmatig zónder `--silent` te
draaien.

**2. Niemand werd gewaarschuwd.** Een falende user-timer is onzichtbaar tenzij je er actief naar
kijkt. Op malandro bestaat dat vangnet wel: `modules/rustic-backup.nix` hangt een
`OnFailure=rustic-notify@…` aan elke backup-unit en stuurt een Signal-bericht. Op lobos was daar
niets van.

Dat patroon is niet zomaar over te nemen: de signal-cli REST API op malandro luistert op
`127.0.0.1:8088` en is vanaf lobos onbereikbaar.

## What Changes

- **`--silent` niet meer standaard** in `home/module/nextcloud-sync/`. De vlag verhuist naar een
  nieuwe optie `quiet`, die standaard `false` is. Een falende sync vertelt nu in de journal wat er
  misging.
- **Nieuwe home-manager-module `home/module/notify-signal/`** met één template-unit
  `notify-signal@.service`. Aanhaken via `Unit.OnFailure = [ "notify-signal@%N.service" ]`; `%N`
  vult de naam van de falende unit in, dus één template bedient elke user-service.
- **Route via Home Assistant** (`notify.signal_maria`) in plaats van rechtstreeks signal-cli,
  omdat die API vanaf lobos niet bereikbaar is. Token uit agenix (`secrets/ha-token.age`, bestond
  al maar werd nergens gebruikt).
- **Het bericht bevat de laatste vijf journalregels** van de falende unit, zodat je niet hoeft in
  te loggen om te zien wát er misging.
- **`onFailure`-optie** toegevoegd aan zowel `nextcloud-sync` als `remarkable-sync`, en op beide
  aangezet.
- **`--fail-with-body` op de curl** in het meldscript: zonder `--fail` geeft curl exit 0 bij HTTP
  400/401/500, waardoor een geweigerde melding er als geslaagd uitziet — dezelfde klasse fout als
  `--silent`, in de module die dat juist moet voorkomen.

## Capabilities

### New Capabilities

- `service-failure-notifications`: Meldt het falen van een systemd user-service via Signal, met
  genoeg context om de oorzaak te zien zonder in te loggen.

### Modified Capabilities

- `nextcloud-sync`: logt voortaan de uitvoer van `nextcloudcmd` (nieuwe optie `quiet`, default
  uit) en kan een meldingsunit aanroepen bij falen (`onFailure`).

## Impact

- **Host:** alleen `lobos`.
- **Nieuw:** `home/module/notify-signal/`, en `age.secrets.ha-token` in
  `hosts/lobos/lobos-secrets.nix` (pad `/run/secrets/ha-token`, owner `wtoorren`, mode 0400).
- **Gewijzigd:** `home/module/nextcloud-sync/default.nix`, `home/module/remarkable-sync/default.nix`,
  `home/linux-desktop.nix`, `flake.nix` (module-import), `CHANGELOG.md`.
- **Meer journal-volume:** `nextcloudcmd` logt nu per run. Dat is de bedoeling; wie er last van
  heeft zet `quiet = true`, maar verliest dan weer het zicht op fouten.
- **Meldingen gaan naar `+31636201589`**, hetzelfde nummer als de rustic-backupmeldingen van
  malandro. Afzender is het signal-cli-account `+31612652352`.
- **Buiten scope:** hetzelfde vangnet op malandro (daar bestaat al een eigen mechanisme), en
  meldingen voor system-units in plaats van user-units.
