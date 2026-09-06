## Why

Nextcloud AIO op `bobadela1` (v34.0.3.2, `nxc.toorren.net`) draait nu volledig op de lokale
SATA-disk (`/mnt/ncdata`, 4,1 GiB). We willen de opslag verplaatsen naar de bestaande AWS
S3-bucket (`wto-s3-bucket`, `eu-central-1`) voor vrijwel onbeperkte, off-site groei — zonder de
lokale disk als harde limiet. Naïef S3-via-FUSE (s3fs/mountpoint) is ongeschikt: Nextcloud vereist
POSIX atomic-rename en file-locking, die FUSE-over-S3 niet betrouwbaar levert (corruptierisico,
zelfde les waarom `modules/rustic-backup.nix` bewust géén mountpoint-s3 gebruikt).

JuiceFS lost dit op: een échte POSIX-filesystem met **data in S3** en **metadata in PostgreSQL**.
Rename/lock/atomiciteit worden door de metadata-DB afgehandeld, dus veilig als Nextcloud-datadir.
De metadata draait lokaal op bobadela1 (unix-socket, ~0,1 ms, disk-durable) en wordt via
PostgreSQL logical replication live gesynct naar de bestaande PG16-master op malandro voor DR.

## What Changes

- **Nieuwe host-config `hosts/bobadela1/`** (of module) die op bobadela1 (Linux Mint 22.3, Ubuntu
  24.04-basis — geen NixOS; provisioning-stappen gedocumenteerd, niet als NixOS-module afdwingbaar)
  het volgende opzet:
  - **Lokale PostgreSQL 16** als JuiceFS-metadata-engine (`juicefs_meta`-DB, unix-socket voor de
    mount, `listen_addresses` incl. LAN-IP voor de subscriber). `wal_level = logical`.
  - **JuiceFS-mount** op de Nextcloud-datadir, met data op **eigen S3-prefix**
    `s3://wto-s3-bucket/juicefs/` en een **royale lokale SSD-cache**. Boot-ordering: mount vóór de
    AIO-containers starten.
  - **Eigen IAM-user + policy** voor JuiceFS, gescoped op de `juicefs/`-prefix (níet `hasio`/rustic
    hergebruiken).
- **Logical replication** bobadela1 (publisher, `PUBLICATION juicefs_pub FOR ALL TABLES`) →
  malandro (subscriber, `SUBSCRIPTION juicefs_sub` in doel-DB `juicefs_meta_replica`). Schema vooraf
  via `pg_dump --schema-only` (DDL repliceert niet).
- **Migratie** van de bestaande 4,1 GiB `/mnt/ncdata` naar de JuiceFS-mount (nu klein → overzichtelijk).
- **Rustic-backup uitbreiden** (`modules/rustic-backup.nix` op malandro): een **`juicefs dump`**
  engine-onafhankelijke metadata-export als vangnet meenemen in de dagelijkse rustic→S3 backup,
  plus de gerepliceerde `juicefs_meta_replica`-DB in de `pg-dump.service`-cluster-dump.
- **S3-bucket versioning** op de `juicefs/`-prefix als extra hersteldekking voor de datalaag.

## Capabilities

### New Capabilities
- `juicefs-nextcloud-storage`: JuiceFS als S3-backed POSIX-opslag onder Nextcloud AIO op bobadela1,
  met lokale PostgreSQL-metadata-engine en logical replication naar malandro voor DR. Dekt de
  storage-architectuur, boot-ordering, IAM-scoping, replicatie-topologie en het gecombineerde
  herstelpad (metadata + S3-data).

### Modified Capabilities
- `rustic-backup`: de dagelijkse backup neemt aanvullend een engine-onafhankelijke JuiceFS
  metadata-dump (`juicefs dump`) én de gerepliceerde metadata-DB mee, zodat het herstelpad van de
  nieuwe JuiceFS-opslag gedekt is.

## Impact

- **Nieuwe host in de repo:** `hosts/bobadela1/` (bobadela1 zelf is geen NixOS — de repo documenteert
  en levert config-artefacten/scripts; afdwinging is deels handmatig/imperatief op de Mint-host).
- **Gewijzigd:** `modules/rustic-backup.nix` (manifest + juicefs-dump-stap), `hosts/malandro/`
  (subscription-provisioning, firewall 5432 ← bobadela1), agenix-secrets (JuiceFS IAM-key,
  JuiceFS-repo/format-secret, replicatie-rol-wachtwoord).
- **Nieuwe runtime-koppeling:** malandro-subscriber trekt van bobadela1-publisher (uitgaand naar
  bobadela1:5432). De hete metadata-schrijfweg blijft lokaal op bobadela1 → Nextcloud werkt door
  ook als malandro/LAN wegvalt. Data-pad bobadela1 → S3 loopt over de internet-uplink
  (gemeten ~21 MiB/s upload via de bestaande rustic-runs; LAN-RTT naar malandro ~0,66 ms).
- **AWS:** extra IAM-user/policy; `s3:GetObject/PutObject/DeleteObject/ListBucket` op de
  `juicefs/`-prefix; bucket-versioning aanzetten op die prefix.
- **Nieuwe SPOF-overweging:** JuiceFS-metadata-DB = kritisch; verlies zonder herstel = onleesbare
  S3-data. Vandaar de dubbele dekking (logical replication + native `juicefs dump` in rustic).
