## 1. AWS S3 + IAM voorbereiden

- [x] 1.1 IAM-policy `juicefs-nextcloud-s3` aangemaakt in account 760178553019: `s3:GetObject/PutObject/DeleteObject` op `wto-s3-bucket/juicefs/*` + `s3:ListBucket` met prefix-conditie `juicefs/*`
- [x] 1.2 Dedicated IAM-user `juicefs-nextcloud` + access-key aangemaakt (AccessKeyId `AKIA3B7RMGC5THN23WWQ`), policy attached (níet `hassio` hergebruikt)
- [~] 1.3 Versioning OVERGESLAGEN — S3-versioning is bucket-breed (niet per-prefix); aanzetten zou de rustic-prune-economie breken (noncurrent versions blijven ruimte kosten). Vertrouwelijkheid/herstel wordt gedekt door JuiceFS client-side encryptie (4.x) + `juicefs dump` in rustic (8.x)
- [x] 1.4 Geverifieerd: schrijf-isolatie KLOPT (PUT buiten `juicefs/` en op rustic-prefix → AccessDenied). ⚠️ BEVINDING: bucket-policy `DirectReads` geeft `s3:GetObject` aan `Principal:*` + Block-Public-Access staat UIT → bucket is publiek leesbaar. Mitigatie: JuiceFS client-side encryptie (zie 4.2). Pre-existing publieke-bucket-exposure apart aan user gemeld

## 2. Secrets (agenix, durable in repo; bobadela1 krijgt ze via provisioning-script)

- [x] 2.1 `secrets/juicefs-s3-env.age` — `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` van user `juicefs-nextcloud` (decrypt-roundtrip met malandro host-key geverifieerd)
- [x] 2.2 `secrets/juicefs-rsa-key.age` (RSA-privékey, AES256-encrypted PEM) + `secrets/juicefs-format-passphrase.age` (passphrase) — voor JuiceFS client-side encryptie at-rest
- [x] 2.3 `secrets/juicefs-repl-password.age` — wachtwoord voor de PostgreSQL-replicatie-rol `repl`
- [x] 2.4 `secrets/secrets.nix` bijgewerkt met de vier nieuwe secrets (recipients users + wtoorren_workstation + malandro_workstation)
- [x] 2.5 (in rbw gezet) ⚠️ Repo-passphrase + RSA-key OFFLINE bewaren (password-manager) — bij verlies is de JuiceFS-data onherstelbaar (zoals rustic-repo-wachtwoord)
- [x] 2.6 Uitgerold naar `/etc/juicefs/` (root 0400) + vastgelegd in `hosts/bobadela1/provision.sh`. Provisioning-script dat de JuiceFS-secrets (S3-env + RSA-key + passphrase) op bobadela1 uitrolt naar root-only bestanden (bobadela1 = geen NixOS, dus geen agenix-runtime)

## 3. PostgreSQL 16 op bobadela1 (publisher)

- [x] 3.1 `postgresql-16` installeren (apt) en de service enablen
- [x] 3.2 `postgresql.conf`: `wal_level = logical`, `listen_addresses = 'localhost,192.168.2.67'`, restart
- [x] 3.3 `pg_hba.conf`: `host juicefs_meta repl 192.168.2.52/32 scram-sha-256`
- [x] 3.4 ufw is inactive op bobadela1; toegang beperkt via `listen_addresses` (localhost+192.168.2.67) + `pg_hba` (`juicefs_meta` alleen vanaf 192.168.2.52/32). Genoteerd voor docs
- [x] 3.5 `CREATE ROLE repl WITH REPLICATION LOGIN PASSWORD …` (wachtwoord uit 2.3)
- [x] 3.6 `CREATE DATABASE juicefs_meta`
- [x] 3.7 Vastgelegd in `hosts/bobadela1/README.md` + `provision.sh`. Provisioning vastleggen als idempotent script/documentatie in `hosts/bobadela1/`

## 4. JuiceFS installeren en formatteren op bobadela1

- [x] 4.1 JuiceFS-client installeren (vaste versie pinnen)
- [x] 4.2 `juicefs format` tegen `postgres://…@localhost/juicefs_meta` + `s3://wto-s3-bucket/juicefs` (region eu-central-1), **met client-side encryptie** (`--encrypt-rsa-key` = RSA-key uit 2.2, `JFS_RSA_PASSPHRASE` uit passphrase-secret) → data = ciphertext in de publieke bucket
- [x] 4.3 Verifiëren: alle JuiceFS-metadata-tabellen hebben een PK/`REPLICA IDENTITY` (nodig voor logical replication)
- [x] 4.4 Vaststellen of JuiceFS Postgres-`SEQUENCE`s of counter-rijen gebruikt (documenteren i.v.m. restore/promote)
- [x] 4.5 `--backup-meta` (periodieke metadata-backup naar de object-store) aan laten staan/instellen
- [x] 4.6 Testmount op tijdelijk pad; POSIX-check: `rename(2)` atomair + `flock` gehonoreerd; smoke-test lezen/schrijven → S3

## 5. Logical replication naar malandro (subscriber)

- [x] 5.1 Op bobadela1: `CREATE PUBLICATION juicefs_pub FOR ALL TABLES`
- [x] 5.2 Schema naar malandro kopiëren: `pg_dump --schema-only -h bobadela1 juicefs_meta | psql juicefs_meta_replica`
- [x] 5.3 Op malandro: `CREATE DATABASE juicefs_meta_replica` (indien nog niet) en `CREATE SUBSCRIPTION juicefs_sub CONNECTION … PUBLICATION juicefs_pub`
- [x] 5.4 Verifiëren: initiële copy voltooid en nieuwe changes stromen live door (test-write op bobadela1 → zichtbaar in replica)
- [x] 5.5 Verifiëren: publisher schrijft door tijdens subscriber-downtime en subscriber haalt bij na herstel
- [~] 5.6 Malandro-subscriber imperatief opgezet (psql) + gedocumenteerd in README; niet als declaratieve nix-module (subscription met wachtwoord is lastig declaratief). malandro NixOS-kant vastleggen (firewall/uitgaand naar bobadela1:5432; subscription-provisioning gedocumenteerd/gescript)

## 6. Boot-ordering + mount op de Nextcloud-datadir

- [x] 6.1 systemd-unit voor de JuiceFS-mount met royale lokale SSD-cache-dir (grootte bepalen op basis van vrije ruimte `/dev/sda3`)
- [x] 6.2 Mount-unit afhankelijk maken van de lokale PostgreSQL (`After=`/`Requires=`)
- [x] 6.3 Nextcloud AIO-containerservice ordenen ná de mount (`RequiresMountsFor`/`After=`) zodat de datadir nooit leeg opstart
- [x] 6.4 (reboot-test geslaagd: mount vóór docker, datadir niet leeg, containers healthy, HTTP 200) Reboot-test: na herstart is de mount actief vóór de AIO-stack; containers healthy

## 7. Datamigratie

- [x] 7.1 AIO stoppen
- [x] 7.2 `/mnt/ncdata` → JuiceFS-mount kopiëren met `rsync -a --checksum` en integriteit verifiëren
- [x] 7.3 Mount op de datadir-locatie activeren; AIO starten
- [x] 7.4 `occ files:scan --all` en functioneel verifiëren: up/download via `nxc.toorren.net`, filesync-client
- [~] 7.5 (uitgesteld) Originele `/mnt/ncdata` intact bewaren tot verificatie compleet is; daarna opruimen

## 8. Rustic-backup uitbreiden (malandro)

- [x] 8.1 GEDEKT zonder extra tooling: JuiceFS `--backup-meta 1h` schrijft auto metadata-dumps naar `s3://…/juicefs/meta/`, én `juicefs_meta_replica` zit in `pg_dumpall` (rustic). `modules/rustic-backup.nix`: stap toevoegen die een recente `juicefs dump`-JSON in het backup-manifest opneemt (bobadela1 dumpt en pusht, óf malandro genereert uit de replica — keuze uit design Open Questions)
- [x] 8.2 `pg-dump.service` dekt `juicefs_meta_replica` mee in de cluster-dump (verifiëren dat `pg_dumpall` de nieuwe DB bevat)
- [x] 8.3 Bevestigen dat de JuiceFS-mount NIET in de rustic-bronnen staat (geen S3→S3-recursie)
- [~] 8.4 GEEN rustic-moduewijziging nodig (dekking is automatisch via pg_dumpall); losse rustic-run niet opnieuw getriggerd. malandro rebuilden; `rustic-backup.service` handmatig draaien
- [~] 8.5 (uitgesteld) Restore-round-trip: `juicefs dump` + S3-`juicefs/`-prefix → `juicefs load` in lege engine → remount + integriteit ok

## 9. Documentatie

- [x] 9.1 `hosts/bobadela1/` provisioning-stappen + herstelpad (metadata + data) documenteren
- [~] 9.2 bobadela1-poorten/mount gedocumenteerd in `hosts/bobadela1/README.md`; PORTS.md (malandro-scope) niet geraakt. `PORTS.md`/relevante docs bijwerken (5432 replicatie, JuiceFS-mount)
- [x] 9.3 CHANGELOG onder `## NEXT VERSION` bijwerken (Added/Changed) vóór archivering
