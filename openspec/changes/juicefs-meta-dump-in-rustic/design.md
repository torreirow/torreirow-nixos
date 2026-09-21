# Design

## Context

De backup draait om 03:00 op malandro. bobadela1 (waar de JuiceFS RW-mount + live
PostgreSQL-metadata leeft) is dan **uit** (nightly-shutdown 23:00, WoL-wake 09:00). Een live
`juicefs dump` tegen bobadela1 zou dus elke nacht falen.

Bestaande dekking van de JuiceFS-metadata:

| Bron | Mechanisme | In rustic? | Formaat |
|------|-----------|-----------|---------|
| `juicefs_meta_replica` | logische replicatie → `pg_dumpall` | ✅ ja | Postgres-schema-specifiek |
| `--backup-meta 1h` | juicefs schrijft dumps → `s3://…/juicefs/meta/` | ❌ nee | **versleuteld** (aes256gcm-rsa) |

## Onderzochte bronnen

Drie kandidaten, empirisch getoetst:

- **Live `juicefs dump` tegen bobadela1** — afgevallen: host staat om 03:00 uit.
- **De `--backup-meta`-export uit S3 overnemen** — afgevallen na test: de objecten zijn client-side
  **versleuteld**. Een `aws s3 cp` levert een ciphertext-blob (`file` → "data", geen gzip/JSON) die
  alleen met de JuiceFS-RSA-sleutel én een juicefs-client terug te lezen is. Geen bruikbare,
  inspecteerbare JSON → voldoet niet aan de spec-eis.
- **`juicefs dump` tegen de lokale `juicefs_meta_replica`** — gekozen. De Postgres-metadata is
  **niet** versleuteld (alleen de object-store-data is dat), dus de dump levert schone plaintext
  JSON met de volledige `FSTree`. Werkt om 03:00 zonder bobadela1. juicefs scrubt zelf de S3-secret
  uit de export (`SecretKey: "removed"`).

### Onafhankelijkheid vs. correlatie

De JSON komt uit dezelfde replica als de pg-dump, dus qua **versheid** zijn ze gecorreleerd (breekt
de logische replicatie stil, dan zijn beide oud). De toegevoegde waarde zit in **format-onafhankelijkheid**:
de `juicefs load`-bare JSON overleeft een JuiceFS- of Postgres-schemawijziging die de pg-dump
onbruikbaar zou maken. Echte bron-onafhankelijkheid (live engine) is om 03:00 sowieso onmogelijk.

## Implementatie

Nieuwe oneshot `juicefs-meta-dump.service`, zelfde vorm als de bestaande dump-services
(`dumpService`-helper + `OnFailure=rustic-notify@`):

- `runuser -u postgres -- juicefs dump "postgres://postgres@/juicefs_meta_replica?host=/run/postgresql&sslmode=disable"`
  — unix-socket **peer-auth** als de `postgres`-OS-gebruiker; geen nieuw role of secret nodig.
- Root opent de output-fd (`> "$tmp"`) in de 0700-staging-dir; postgres schrijft erin (zelfde
  fd-patroon als pg-dump dat naar root's zstd pipet). `jq -e` valideert de JSON vóór `mv -f`.
- `rustic-backup.service`: `juicefs-meta-dump.service` toegevoegd aan `after`/`wants` (niet
  `requires` — een onbereikbare replica blokkeert de rest van de backup niet; de vorige dump blijft
  dan in het manifest en er komt een Signal-alert).

## Risico's / mitigaties

- **S3 AccessKey-ID in de JSON**: de `SecretKey` is gescrubd, maar het access-key-**ID** blijft in
  `Setting`. Dat landt uitsluitend in de 0700-staging-dir en de **versleutelde** rustic-repo, en
  staat identiek al in de pg-replica-dump. Acceptabel.
- **Stille replicatie-breuk** → verouderde dump: buiten scope (monitoring van de subscription is een
  aparte zorg); de `OnFailure`-alert dekt alleen harde fouten.
