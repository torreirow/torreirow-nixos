# rustic-backup Specification

## Purpose
TBD - created by archiving change add-rustic-s3-backup. Update Purpose after archive.
## Requirements
### Requirement: Dagelijkse backup via systemd timer
Het systeem SHALL dagelijks om 03:00 een rustic-backup draaien via `rustic-backup.timer` met `Persistent=true`, zodat een gemiste run na downtime wordt ingehaald.

#### Scenario: Timer actief na rebuild
- **WHEN** malandro is gerebuild met de module
- **THEN** toont `systemctl list-timers` de `rustic-backup.timer` met een volgende trigger om 03:00

#### Scenario: Gemiste run wordt ingehaald
- **WHEN** de host om 03:00 uit stond en later weer opstart
- **THEN** draait `rustic-backup.service` alsnog vanwege `Persistent=true`

### Requirement: Databases worden logisch gedumpt vóór de backup
Het systeem SHALL PostgreSQL, MariaDB en de Vaultwarden-SQLite dumpen naar `/var/backup/db/` via aparte, los-draaibare oneshot-services, en de `rustic-backup.service` SHALL via `After=`/`Wants=` ná die dumps draaien.

#### Scenario: PostgreSQL-dump
- **WHEN** `pg-dump.service` draait
- **THEN** bevat `/var/backup/db/pg-all.sql.zst` een `pg_dumpall` van alle databases inclusief roles/globals

#### Scenario: MariaDB-dump
- **WHEN** `mariadb-dump.service` draait
- **THEN** bevat `/var/backup/db/mysql-all.sql.zst` een `mysqldump --all-databases --single-transaction`

#### Scenario: Vaultwarden-SQLite-dump zonder downtime
- **WHEN** `vaultwarden-dump.service` draait terwijl de vaultwarden-container actief is
- **THEN** wordt via `sqlite3 .backup` een consistent snapshot `/var/backup/db/vaultwarden.sqlite3` gemaakt zonder de container te stoppen

#### Scenario: Dumps zijn onafhankelijk draaibaar
- **WHEN** een beheerder `systemctl start pg-dump.service` uitvoert
- **THEN** draait alleen die dump, zonder de rustic-backup te triggeren

### Requirement: Off-site backup naar AWS S3 zonder FUSE
Het systeem SHALL de backup rechtstreeks naar S3 schrijven via de rustic opendal-s3 backend naar `s3://wto-s3-bucket` in region `eu-central-1` met prefix `/rustic-backup/malandro`. Het systeem SHALL GEEN mountpoint-s3/FUSE-mount gebruiken.

#### Scenario: Repo wordt bij eerste run geïnitialiseerd
- **WHEN** `rustic-backup.service` draait tegen een nog niet bestaande repo
- **THEN** initialiseert de service de repo idempotent (repoinfo-check → init) voordat de backup start

#### Scenario: Backup dekt beide roots
- **WHEN** de backup draait
- **THEN** worden zowel `/var/lib/*` container-state als de gecureerde `/data/external/*` paden én de DB-dumps in de snapshot opgenomen

### Requirement: Credentials via agenix, nooit in nix-store of proceslijst
Het systeem SHALL de AWS-credentials uit een agenix env-file (`/run/agenix/rustic-s3-env`) via `EnvironmentFile=` laden en met `${VAR}`-substitutie (`--profile-substitute-env`) in het profiel injecteren, en het repo-encryptie-wachtwoord via een agenix password-file (`/run/agenix/rustic-repo-password`) gebruiken.

#### Scenario: Geen geheim in het profiel
- **WHEN** het profiel `/etc/rustic/malandro.toml` wordt gelezen
- **THEN** bevat het alleen `${AWS_ACCESS_KEY_ID}` / `${AWS_SECRET_ACCESS_KEY}` placeholders, geen echte sleutels

#### Scenario: Repo is versleuteld
- **WHEN** de repo wordt aangemaakt
- **THEN** is die versleuteld met het wachtwoord uit `/run/agenix/rustic-repo-password`

### Requirement: Live database-bestanden worden uitgesloten van de file-backup
Het systeem SHALL de live Vaultwarden-SQLite-bestanden (`db.sqlite3`, `db.sqlite3-wal`, `db.sqlite3-shm`) uitsluiten van de file-level backup, zodat alleen het consistente dump-snapshot wordt geback-upt.

#### Scenario: Live sqlite uitgesloten
- **WHEN** de backup `/var/lib/vaultwarden` verwerkt
- **THEN** bevat de snapshot NIET `db.sqlite3`/`-wal`/`-shm`, maar wél `attachments`, `sends`, `rsa_key.pem` en `config.json`

### Requirement: Retentie via forget/prune
Het systeem SHALL na elke backup `rustic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --prune` draaien.

#### Scenario: Oude snapshots worden opgeruimd
- **WHEN** er meer dan 7 dagelijkse snapshots bestaan
- **THEN** verwijdert `forget --prune` de snapshots buiten het retentiebeleid en geeft de S3-opslag vrij

### Requirement: Faal-notificatie via Signal
Het systeem SHALL bij het falen van een dump- of backup-service een Signal-melding sturen via `OnFailure=` via de lokale signal-cli REST API (afzender +31612652352, ontvanger +31636201589).

#### Scenario: Melding bij fout
- **WHEN** een van de vier services faalt
- **THEN** stuurt `rustic-notify@<unit>.service` een Signal-bericht met de hostnaam en de gefaalde unit

