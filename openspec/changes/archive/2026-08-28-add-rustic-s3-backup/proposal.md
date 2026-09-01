## Why

Malandro draait tientallen zelf-gehoste services, maar er is geen geautomatiseerde off-site backup. Bij een schijf- of hostcrash (zie het lopende sdb SATA-link-drop incident) is er geen betrouwbare weg terug: geen versleutelde off-site kopie van de container-state, en geen logische dumps van PostgreSQL, MariaDB en de Vaultwarden-SQLite. Dit voegt een dagelijkse, versleutelde, incrementele backup naar AWS S3 toe met [rustic](https://github.com/rustic-rs/rustic), plus disaster-recovery database-dumps zodat in geval van nood alles schoon teruggezet kan worden.

## What Changes

- Nieuwe NixOS module `modules/rustic-backup.nix` (import in `hosts/malandro/configuration.nix`)
- Drie los-draaibare dump-services die naar staging-dir `/var/backup/db/` schrijven:
  - `pg-dump.service` — `pg_dumpall` (alle PostgreSQL-DBs + roles/globals), zstd-gecomprimeerd
  - `mariadb-dump.service` — `mysqldump --all-databases --single-transaction`
  - `vaultwarden-dump.service` — `sqlite3 .backup` (consistent WAL-snapshot, geen downtime)
- `rustic-backup.service` — file-level backup van het manifest (twee roots: `/var/lib/*` + gecureerd `/data/external/*`) plus de DB-dumps, gevolgd door `rustic forget --prune`
- `rustic-backup.timer` — dagelijks 03:00, `Persistent=true`
- Faal-notificatie via Signal (template-unit `rustic-notify@`, lokale signal-cli REST API `v2/send`) op `OnFailure=` van elke service
- rustic praat **direct** met S3 via de opendal-s3 backend (geen mountpoint-s3/FUSE)
- Repo-config als `/etc/rustic/malandro.toml`; AWS-creds via agenix env-file + `${VAR}`-substitutie, repo-encryptie-wachtwoord via agenix password-file
- Twee nieuwe agenix secrets: `rustic-s3-env.age`, `rustic-repo-password.age` (reeds door gebruiker aangemaakt)

## Capabilities

### New Capabilities

- `rustic-backup`: dagelijkse, versleutelde, incrementele off-site backup naar AWS S3 (`wto-s3-bucket`, region `eu-central-1`, prefix `/rustic-backup/malandro`) van alle persistente container-state en logische database-dumps, met retentie keep-daily 7 / keep-weekly 4 / keep-monthly 3 en faal-notificatie via Signal

## Impact

- `modules/rustic-backup.nix` — nieuw bestand
- `hosts/malandro/configuration.nix` — import toevoegen
- `secrets/secrets.nix` — twee rustic-entries (reeds toegevoegd)
- `secrets/rustic-s3-env.age`, `secrets/rustic-repo-password.age` — nieuw (reeds aangemaakt)
- Nieuwe staging-dir `/var/backup/db` (0700 root)
- Vereist eenmalig: IAM-user `hasio` met `s3:DeleteObject` in policy (voor prune) — reeds toegevoegd in AWS
- Geen impact op draaiende services: alle units zijn oneshot/timer en raken bestaande containers niet
