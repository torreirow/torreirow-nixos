## Context

Zie `proposal.md` — Why. Relevante huidige staat en beperkingen (deels gemeten in de verkennende
sessie 2026-09-05):

- **bobadela1**: Dell Latitude E5520 (i5-2520M, 2c/4t, AES-NI aanwezig), **Linux Mint 22.3**
  (Ubuntu 24.04-basis) — **geen NixOS**. Passwordless sudo werkt. `nxc.toorren.net` → Nextcloud AIO
  v34.0.3.2, 5 healthy containers, datadir `/mnt/ncdata` (4,1 GiB) op interne SATA `/dev/sda3`
  (457 G, 8% vol). Idle ~6 W CPU-package.
- **malandro**: NixOS, PostgreSQL **16.14** (`wal_level=replica`, `max_logical_replication_workers=4`,
  slots 10, senders 10 — ruim voldoende voor een subscriber-only rol, geen restart nodig).
  Draait de bestaande `modules/rustic-backup.nix` (dagelijks 03:00 → `s3://wto-s3-bucket/rustic-backup/malandro`).
- **Netwerk**: bobadela1 (192.168.2.67) ↔ malandro (192.168.2.52), gigabit, **RTT ~0,66 ms**,
  TCP-connect <1 ms. Postgres op malandro luistert al op `0.0.0.0:5432`.
- **S3-uplink**: gemeten via rustic-runs **~21 MiB/s (~175–180 Mbit/s) upload** naar S3
  (`eu-central-1`); download doorgaans sneller.

Constraint: de repo is NixOS-gericht, maar bobadela1 is imperatief (Mint). De change levert
config-artefacten, scripts en gedocumenteerde provisioning voor bobadela1, en echte NixOS-wijzigingen
alleen op malandro (subscription/firewall) en in `modules/rustic-backup.nix`.

## Goals / Non-Goals

**Goals:**
- POSIX-veilige S3-opslag onder de Nextcloud-datadir via JuiceFS, data op `wto-s3-bucket/juicefs/`.
- Metadata lokaal op bobadela1 (unix-socket, disk-durable) → lage latency + host-zelfstandigheid.
- Live DR-kopie van de metadata op malandro via PostgreSQL logical replication.
- Dubbele metadata-dekking in de backup: logical replication + engine-onafhankelijke `juicefs dump`.
- Veilige migratie van de bestaande 4,1 GiB zonder dataverlies.

**Non-Goals:**
- Geen naadloze hot-standby/automatische failover van de metadata (dat zou fysieke streaming-replicatie
  vereisen; zie Decisions). DR = restore-met-zorg, niet instant promote.
- Geen omzetting naar Nextcloud's native S3 object storage (`\OC\Files\ObjectStore\S3`) — dat is een
  alternatief, niet deze aanpak.
- bobadela1 wordt in deze change niet naar NixOS gemigreerd.
- Geen wijziging aan de bestaande rustic-repo-prefix of -IAM-user.

## Decisions

### D1: JuiceFS i.p.v. FUSE-over-S3 of native Nextcloud-objectstore
JuiceFS geeft een echte POSIX-FS (rename/lock/atomiciteit via de metadata-DB) — precies wat Nextcloud
eist en wat s3fs/mountpoint-s3 niet betrouwbaar leveren (zelfde reden waarom rustic bewust geen FUSE
gebruikt). Boven native objectstore gekozen omdat de gebruiker een general-purpose S3-FS met lokale
cache/compressie wil en al een PostgreSQL beschikbaar heeft; native objectstore vereist bovendien een
lege instance/migratie en levert geen FS voor ander gebruik. **Alternatieven:** mountpoint-s3
(afgewezen: geen rename, read-heavy), native objectstore (afgewezen als hoofdroute, wél genoemd als
optie in het onderzoek).

### D2: PostgreSQL als metadata-engine, niet Redis
Metadata-verlies = dataverlies, dus durability weegt zwaarder dan snelheid. Postgres is disk-durable
by default (WAL + fsync); Redis is in-memory met zwakkere, config-afhankelijke persistentie (AOF).
De gebruiker heeft al PostgreSQL 16. **Alternatief:** Redis (afgewezen: durability + RAM-limiet).

### D3: Metadata lokaal op bobadela1 (publisher), niet remote op malandro
Lokale unix-socket ≈ 0,1 ms i.p.v. ~1 ms over de LAN, én — belangrijker — het verwijdert de
runtime-afhankelijkheid van malandro/LAN: Nextcloud blijft werken als malandro wegvalt. malandro wordt
puur DR-kopie. **Alternatief:** metadata direct op malandro (afgewezen: cross-host runtime-SPOF +
latency).

### D4: Logical replication (bobadela1 publisher → malandro subscriber)
Levert een live kopie ván de metadata-DB ín de bestaande malandro-master, zonder malandro's cluster te
herconfigureren (subscriber-only, `wal_level=replica` volstaat, geen restart). `PUBLICATION ... FOR ALL
TABLES` vangt ook nieuwe JuiceFS-tabellen. **Alternatief:** fysieke streaming-replicatie (optie C) —
completer voor DR (repliceert sequences byte-voor-byte, naadloze promote), maar vereist een dedicated
standby-instance en koppelt hele clusters; te zwaar voor deze low-churn filesync. Gekozen: logical +
`juicefs dump`-vangnet dekt de gaten van logical (zie D5/R2).

### D5: Dubbele metadata-dekking in de backup
Naast logical replication neemt rustic een engine-onafhankelijke `juicefs dump`-JSON mee én de
gerepliceerde `juicefs_meta_replica`-DB (via de bestaande `pg-dump.service`). `juicefs dump` is
engine-agnostisch en dekt exact de zwaktes van logical replication (geen DDL, sequences) bij restore.
JuiceFS' eigen periodieke metadata-backup naar de object-store (`--backup-meta`) blijft bovendien aan.

### D6: Eigen S3-prefix + eigen IAM-user
`wto-s3-bucket/juicefs/` gescheiden van `rustic-backup/malandro`; aparte IAM-key gescoped op die prefix
(`Get/Put/Delete/List`), niet `hasio` hergebruiken → een lek raakt de backup-repo niet. Secrets via
agenix-conventie (`/run/agenix/…`). Bucket-versioning aan op de `juicefs/`-prefix.

### D7: Migratie via kopie naar de mount, met AIO gestopt
JuiceFS mounten op een tijdelijk pad, AIO stoppen, `/mnt/ncdata` → mount kopiëren (rsync, checksum),
mount op de datadir-locatie zetten, AIO starten, `occ files:scan`. 4,1 GiB @ ~20 MiB/s ≈ enkele
minuten upload. Rollback: AIO terug op de originele `/mnt/ncdata` (die intact blijft tot verificatie).

## Risks / Trade-offs

- **Metadata-DB = SPOF** → Mitigatie: disk-durable lokale Postgres + logical replication naar malandro
  + engine-onafhankelijke `juicefs dump` in rustic + JuiceFS `--backup-meta` naar S3. Viervoudige dekking.
- **R2: Logical replication repliceert geen DDL en (mogelijk) geen sequences** → Mitigatie: schema
  vooraf via `pg_dump --schema-only`; bij JuiceFS-schema-upgrades schema handmatig bijtrekken; voor
  restore/promote vertrouwen op `juicefs dump`/`load` i.p.v. de ruwe SQL-replica. Verifieer na `format`
  of JuiceFS Postgres-`SEQUENCE`s of counter-rijen gebruikt (rijen repliceren wél).
- **R3: Replica identity/PK ontbreekt op een tabel** → UPDATE/DELETE repliceren niet. Mitigatie:
  na `juicefs format` controleren dat alle tabellen een PK/`REPLICA IDENTITY` hebben.
- **R4: Data-pad hangt aan de internet-uplink (~175 Mbit/s upload)** → Mitigatie: royale lokale
  SSD-cache op bobadela1 vangt reads; low-churn filesync genereert weinig verkeer; migratie is klein.
- **R5: bobadela1 is imperatief (Mint), niet reproduceerbaar via Nix** → Mitigatie: provisioning als
  gedocumenteerde, idempotente stappen/scripts in `hosts/bobadela1/`; alleen malandro-kant is echt Nix.
- **R6: Nieuwe firewall-opening 5432 op bobadela1 ← malandro** → Mitigatie: `pg_hba` + host-firewall
  strikt op `192.168.2.52/32`, scram-sha-256, dedicated replicatie-rol met minimale rechten.
- **R7: AIO-datadir-checks / boot-race** → Mitigatie: mount-unit met `RequiresMountsFor`/ordering vóór
  de container-service; verifieer AIO's datadir-acceptatie na de switch.

## Migration Plan

1. **Voorbereiden (niet-disruptief):** IAM-user + policy + agenix-secrets; bucket-versioning op
   `juicefs/`; PostgreSQL 16 op bobadela1 installeren (`wal_level=logical`, `listen_addresses`,
   `pg_hba` voor malandro); JuiceFS installeren.
2. **Formatteren:** `juicefs format` tegen `postgres://…@localhost/juicefs_meta` + `s3://…/juicefs`.
   Tabellen/PK/replica-identity verifiëren.
3. **Replicatie opzetten:** publication op bobadela1; schema naar malandro (`pg_dump --schema-only`);
   `CREATE SUBSCRIPTION` op malandro; verifieer dat changes doorkomen.
4. **Migreren:** AIO stoppen; `/mnt/ncdata` → JuiceFS-mount (rsync --checksum); mount op datadir zetten
   met boot-ordering; AIO starten; `occ files:scan`; functioneel verifiëren (up/download, versioning).
5. **Backup uitbreiden:** `modules/rustic-backup.nix` — `juicefs dump`-stap + `juicefs_meta_replica` in
   de cluster-dump; malandro rebuild; run + restore-round-trip testen.
6. **Rollback (elke stap):** AIO terug op de intacte originele `/mnt/ncdata`; subscription/publication
   droppen; mount unmounten. Originele data blijft behouden tot expliciete verificatie + opruiming.

## Open Questions

- Exacte cache-dir-grootte op bobadela1's SSD (afh. van vrije ruimte op `/dev/sda3`) — verfijnbaar
  tijdens implementatie, verandert de specs/aanpak niet.
- Of `juicefs dump` op bobadela1 draait (en het bestand naar malandro gepusht wordt) of dat malandro het
  via de replica genereert — implementatiedetail voor de backup-stap.
