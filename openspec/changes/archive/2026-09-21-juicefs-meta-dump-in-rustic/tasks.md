## 1. Dump-service toevoegen

- [x] 1.1 In `modules/rustic-backup.nix` een `juicefsMetaDumpScript` toevoegen: `juicefs dump` tegen `juicefs_meta_replica` via unix-socket peer-auth (`runuser -u postgres`), output atomisch naar `/var/backup/db/juicefs-meta-dump.json` (`> "$tmp"` als root, `jq -e`-validatie, `mv -f`, `umask 077`)
- [x] 1.2 `systemd.services.juicefs-meta-dump` definiëren via de bestaande `dumpService`-helper (geen EnvironmentFile/secret nodig — peer-auth)
- [x] 1.3 `rustic-backup.service` uitbreiden: `juicefs-meta-dump.service` toegevoegd aan `after` en `wants` (niet `requires`)

## 2. Spec bijwerken

- [x] 2.1 Delta in `specs/rustic-backup/spec.md` (MODIFIED Requirement) verwerkt het aangescherpte scenario met de replica-bron

## 3. Bouwen & verifiëren

- [x] 3.1 `sudo nixos-rebuild switch --flake .#malandro` schoon
- [x] 3.2 `systemctl start juicefs-meta-dump.service` → `/var/backup/db/juicefs-meta-dump.json` (9.1 M) bestaat; `jq -e` valideert
- [x] 3.3 `juicefs load`-baarheid bevestigd via structuur: top-level `Counters, DelFiles, FSTree, Setting, Sustained, Trash`; `Setting.SecretKey == "removed"` (gescrubd)
- [x] 3.4 `systemctl start rustic-backup.service` → nieuwe snapshot bevat `var/backup/db/juicefs-meta-dump.json` (`rustic ls latest`)
- [x] 3.5 Faal-pad statisch geverifieerd: `rustic-backup.service` heeft de dump in `Wants=` (niet `Requires=`) + `After=`; `OnFailure=rustic-notify@juicefs-meta-dump.service` aanwezig (geen live Signal-test om de gebruiker niet te spammen)

## 4. Afronden

- [x] 4.1 Stale Option-B tmp-blob (`juicefs-meta-dump.json.gz.tmp`) uit de staging-dir verwijderd
- [ ] 4.2 CHANGELOG bijwerken onder `## NEXT VERSION`
- [ ] 4.3 Committen (branch, geen self-promoting trailers) en archiveren volgens OpenSpec-stappen
