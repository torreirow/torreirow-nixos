# Design — add-rustic-s3-backup

## Architectuur

```
rustic-backup.timer (03:00, Persistent)
   └─▶ rustic-backup.service  (Wants= + After= de 3 dumps)
        ├─ pg-dump.service        → /var/backup/db/pg-all.sql.zst
        ├─ mariadb-dump.service   → /var/backup/db/mysql-all.sql.zst
        ├─ vaultwarden-dump.service → /var/backup/db/vaultwarden.sqlite3
        └─ rustic backup <manifest> + forget --prune
             └─▶ s3://wto-s3-bucket/rustic-backup/malandro/  (opendal-s3, versleuteld)
   elke unit: OnFailure=rustic-notify@<unit>.service  → Signal
```

## Kernbesluiten

### Direct naar S3, geen mountpoint-s3
mountpoint-s3 (FUSE) ondersteunt geen rename/lock/atomic-replace — precies de operaties die een rustic-repo nodig heeft. rustic's opendal-s3 backend praat native met S3 en regelt locking/atomiciteit/retries zelf. `/data/s3` wordt dus geen mount maar een repo-URL.

### Databases logisch dumpen, niet raw file-copyen
Een live PostgreSQL-datadir of een WAL-mode SQLite file-level kopiëren geeft torn/inconsistente backups. Daarom aparte dump-services:
- **PostgreSQL**: `pg_dumpall --clean --if-exists` (alle DBs + roles/globals) als user `postgres` via `runuser`.
- **MariaDB**: `mysqldump --all-databases --single-transaction --routines --triggers --events` als root via unix-socket auth.
- **Vaultwarden**: `sqlite3 db.sqlite3 ".backup snapshot"` (online-backup API, checkpoint de WAL, geen downtime). De live `db.sqlite3{,-wal,-shm}` worden juist UITGESLOTEN van de file-backup.

Dumps zijn losse oneshot-services (los te draaien, eigen `OnFailure`). rustic-backup gebruikt `Wants=` (soft): faalt een dump, dan draait de backup alsnog met de rest (de gefaalde dump stuurt zijn eigen notify).

### Twee backup-roots
Persistente container-state staat verdeeld over `/var/lib/*` (homeassistant, vaultwarden, zigbee2mqtt, signal-cli, wg-easy, baikal, mmdl, mosquitto) én gecureerd `/data/external/*`. Alleen `/data/external` zou de helft missen.

### Manifest via excludes-door-omissie
De meeste "excludes" (postgresql, prometheus, registry-mirror, crowdsec, nextcloud, dockerlib, invoiceplane-rommel, image/overlay-layers) worden bereikt door ze simpelweg NIET als source te noemen. Alleen binnen een wél-opgenomen source zijn expliciete excludes nodig (live VW-sqlite + caches; paperless consume/export).

## Geverifieerde rustic-mechanica (0.11.2, lokaal getest 2026-08-28)

| Aspect | Bevinding | Gebruik |
|--------|-----------|---------|
| Env-substitutie | **`${VAR}`** werkt, `{{VAR}}` NIET (bleef letterlijk) | `access_key_id = "${AWS_ACCESS_KEY_ID}"` + `--profile-substitute-env` |
| Glob-richting | **`!pattern` = EXCLUDE**, plain = restrictieve INCLUDE | alléén `!`-excludes gebruiken |
| Profiel-discovery | `-P malandro` vindt `malandro.toml` in de **CWD** | `WorkingDirectory=/etc/rustic` |
| opendal-s3 opties | config-keys: bucket/region/endpoint/root/access_key_id/secret_access_key | in `[repository.options]` |

## Secrets & credential-flow

```
secrets/rustic-s3-env.age        → /run/agenix/rustic-s3-env   (EnvironmentFile van de service)
   AWS_ACCESS_KEY_ID=…                (IAM-user hasio)
   AWS_SECRET_ACCESS_KEY=…
secrets/rustic-repo-password.age → /run/agenix/rustic-repo-password  (password-file in profiel)
```

Het profiel `/etc/rustic/malandro.toml` staat plain in de nix-store maar bevat alleen `${AWS_…}`-placeholders. De echte keys komen op runtime uit de EnvironmentFile en worden door `--profile-substitute-env` gesubstitueerd → nooit in nix-store, unit-file of `ps`.

Signal-notificatie gaat via de lokale signal-cli REST API (`http://127.0.0.1:8088/v2/send`, jq bouwt de JSON) naar +31636201589. Geen agenix-secret nodig: de Signal-nummers zijn niet geheim en staan plain in de module (net als in de HA-config).

### Kip-en-ei
Het `rustic-repo-password` moet OOK buiten deze backup bewaard blijven (password-manager + offline). Niet uitsluitend in Vaultwarden — dat wordt door rustic geback-upt (circulair). Bij verlies is de repo onherstelbaar.

## Idempotente init
`rustic-backup.service` doet vóór de backup een `repoinfo`-check; faalt die (verse repo), dan `rustic init`. De repo wordt dus bij de eerste run automatisch geïnitialiseerd — niet op switch-tijd, alleen bij timer/handmatige trigger, zodat een live-rebuild geen S3-afhankelijkheid krijgt.

## Retentie
`rustic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --prune` na elke backup. Prune vereist `s3:DeleteObject` (in policy `hasio` aanwezig).
