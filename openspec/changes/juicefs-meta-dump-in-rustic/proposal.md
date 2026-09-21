## Why

De rustic-backup-spec eist voor de JuiceFS/Nextcloud-metadata **twee onafhankelijke
representaties**: de gerepliceerde `juicefs_meta_replica`-DB (via `pg_dumpall`) én een
engine-onafhankelijke, `juicefs load`-bare **plaintext JSON-export**. Alleen de eerste is live: de
JSON is nooit in het rustic-manifest terechtgekomen (change `add-juicefs-nextcloud-storage`, taak
8.4 koos bewust "geen module-wijziging nodig, `pg_dumpall` dekt het").

Daardoor bevat rustic nu enkel een **PostgreSQL-schema-specifieke** kopie. Bij een JuiceFS- of
Postgres-schemawijziging is die mogelijk niet terug te laden, terwijl een `juicefs dump`-JSON altijd
een verse engine opbouwt. Spec en implementatie liepen dus uiteen.

Twee voor de hand liggende bronnen bleken niet bruikbaar (onderzocht, zie `design.md`):
live `juicefs dump` tegen bobadela1 kan niet — die staat om 03:00 uit (shutdown 23:00, wake 09:00);
en de `--backup-meta`-export in `s3://…/juicefs/meta/` is **client-side versleuteld**
(`aes256gcm-rsa`) → een rauwe kopie is ciphertext, geen JSON. De werkende bron is de lokale
`juicefs_meta_replica`-DB: de Postgres-metadata is niet versleuteld, dus `juicefs dump` daartegen
levert schone, volledige JSON.

## What Changes

- Nieuwe oneshot-service `juicefs-meta-dump.service` in `modules/rustic-backup.nix` die `juicefs dump`
  draait tegen de lokale `juicefs_meta_replica` (unix-socket peer-auth als `postgres`, géén secret) en
  de plaintext JSON naar `/var/backup/db/juicefs-meta-dump.json` schrijft (staging-dir = al een
  rustic-bron).
- `rustic-backup.service` krijgt `Wants=`/`After=` op de nieuwe service (zelfde patroon als de
  bestaande dump-services; een gefaalde dump blokkeert de backup niet maar stuurt wél een
  Signal-melding via `OnFailure=rustic-notify@`).
- Spec-scenario "Engine-onafhankelijke metadata-dump in de backup" aangescherpt met de concrete bron
  (dump uit de lokale replica → JSON → rustic-manifest).

## Non-goals

- Geen live-dump tegen bobadela1 en geen overname van de versleutelde `--backup-meta`-blob.
- Geen nieuw Postgres-role of secret: peer-auth als `postgres` volstaat.
- Geen restore-round-trip-automatisering (blijft handmatige DR-stap).

## Capabilities

### Modified Capabilities

- `rustic-backup`: het scenario voor de engine-onafhankelijke JuiceFS-metadata-dump wordt
  aangescherpt met de concrete bron (`juicefs dump` uit de lokale replica → rustic-manifest).

## Impact

- `modules/rustic-backup.nix` — nieuwe `juicefs-meta-dump`-service + wiring in `rustic-backup.service`.
- `openspec/specs/rustic-backup/spec.md` — bij archivering bijgewerkt via de delta.
- Geen nieuwe secrets; geen gedragswijziging voor de andere backup-onderdelen.
