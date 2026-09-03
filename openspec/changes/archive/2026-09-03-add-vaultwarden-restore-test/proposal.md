## Why

De rustic S3-backup is live, maar een backup is pas een backup als je bewezen hebt dat je 'm kunt terugzetten. De handmatige restore-verificatie tijdens de oplevering was eenmalig en ad-hoc. We willen een herhaalbaar script dat de volledige Vaultwarden-restore doet — inclusief de sterkste proef: daadwerkelijk in- en ontsleutelen met `rbw` — zonder de live Vaultwarden of de echte rbw-config aan te raken, plus een `--destroy` om alles op te ruimen.

## What Changes

- Nieuw script `vaultwarden-restoretest.sh`, gedeployed naar `~/bin/` via home-manager (patroon van `home/module/ssh-config_hosts/export-ssh-keys.sh`)
- Nieuwe home-manager module `home/module/vaultwarden-restore-test/` (bron-script + `home.file."bin/vaultwarden-restoretest.sh"`), geïmporteerd via `home/linux-server.nix`
- Het script:
  - **basis-test** (default): `rustic restore` van de nieuwste snapshot uit S3 → dump wordt `db.sqlite3` (reassemble) → wegwerp-container op `127.0.0.1:8099` (bridge) → `curl /alive` + sqlite-tellingen (users/ciphers)
  - **`--rbw`**: geïsoleerde rbw-crypto-test — login met echte master-password + **TOTP** (2FA blijft staan) tegen de gerestorede instance → `rbw sync` + `rbw list` → bewijst dat de vault écht ontsleutelt
  - **`--snapshot <id>`**: kies een specifieke backup (default: `latest`)
  - **`--destroy`**: ruim container + tmp-data + geïsoleerde rbw-agent/config op
  - **`--keep` / `--help`**
- rbw-isolatie via **XDG_*-override** onder de werkmap → eigen config + eigen `rbw-agent`, volledig los van de echte rbw (`~/.config/rbw`, `vw.toorren.net`)

## Capabilities

### New Capabilities

- `vaultwarden-restore-test`: herhaalbaar, non-destructief script dat een Vaultwarden-backup uit S3 volledig terugzet in een wegwerp-container en optioneel via een geïsoleerde rbw-client (master-pw + TOTP) bewijst dat de vault ontsleutelbaar is, met een `--destroy` opruimfunctie

## Impact

- `home/module/vaultwarden-restore-test/default.nix` — nieuwe HM-module
- `home/module/vaultwarden-restore-test/vaultwarden-restoretest.sh` — het script (bron in repo)
- `home/linux-server.nix` — import toevoegen
- Deployt `~/bin/vaultwarden-restoretest.sh` (home-manager switch vereist)
- Leunt op bestaande rustic-repo (`/etc/rustic/malandro.toml`, `/run/agenix/rustic-s3-env`) en docker; geen nieuwe secrets
- Geen impact op live Vaultwarden of live rbw-config (strikt geïsoleerd)
