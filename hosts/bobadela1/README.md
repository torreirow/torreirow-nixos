# bobadela1 — Nextcloud op JuiceFS (S3) + PostgreSQL-metadata

> ⚠️ **bobadela1 is GEEN NixOS-host** (Linux Mint 22.3 / Ubuntu 24.04-basis, Dell Latitude E5520,
> testserver). Deze map bevat **geen NixOS-config** maar de **runbook + provisioning-stappen** voor de
> imperatieve setup. De enige echt Nix-beheerde onderdelen zijn de agenix-secrets (in `secrets/`) en de
> malandro-kant (PostgreSQL-subscriber, rustic-backup). Zie OpenSpec-change
> `add-juicefs-nextcloud-storage`.

## Architectuur

```
Nextcloud AIO (docker, nxc.toorren.net)
        │  datadir /mnt/ncdata
        ▼
JuiceFS-mount (POSIX, client-side AES256-GCM+RSA encrypted)
        ├── DATA  → s3://wto-s3-bucket/juicefs/  (AWS eu-central-1, IAM-user juicefs-nextcloud)
        └── META  → PostgreSQL 16 lokaal op bobadela1 (db juicefs_meta, unix-socket)
                         │  logical replication (publisher → subscriber)
                         ▼
                    malandro PostgreSQL 16  (db juicefs_meta_replica)  — live DR-kopie
```

- **Waarom JuiceFS i.p.v. FUSE-S3:** echte POSIX-semantiek (atomic rename, flock) via de metadata-DB;
  s3fs/mountpoint-s3 kunnen dat niet → dataverlies. Geverifieerd: rename atomair + flock-contention.
- **Waarom lokale metadata:** unix-socket ~0,1 ms + host blijft zelfstandig als malandro/LAN wegvalt.
- **Waarom encryptie verplicht:** `wto-s3-bucket` was publiek leesbaar; nu dicht (Block Public Access),
  maar JuiceFS-data blijft sowieso ciphertext in S3 (geverifieerd: plaintext niet in het S3-object).

## Wat er provisioned is (imperatief, op bobadela1)

| Onderdeel | Detail |
|-----------|--------|
| PostgreSQL 16 | cluster `main`; drop-in `/etc/postgresql/16/main/conf.d/juicefs.conf` (`wal_level=logical`, `listen_addresses='localhost,192.168.2.67'`) |
| Rollen | `juicefs` (LOGIN, owner van db `juicefs_meta`), `repl` (REPLICATION LOGIN, voor de subscriber) |
| pg_hba | `juicefs_meta` — `juicefs` vanaf 127.0.0.1/::1, `repl` vanaf 192.168.2.52/32 (scram-sha-256) |
| JuiceFS | client v1.2.3 in `/usr/local/bin/juicefs`; volume `juicefs`, `aes256gcm-rsa`, `--backup-meta 1h` |
| Secrets | `/etc/juicefs/juicefs.env` (root 0400: ACCESS_KEY/SECRET_KEY/META_PASSWORD/JFS_RSA_PASSPHRASE) + `/etc/juicefs/rsa-key.pem` (root 0400) |
| Mount | systemd `juicefs-nextcloud.service` → `/mnt/ncdata`, cache `/var/jfsCache` (20 GB), non-writeback |
| Boot-ordering | drop-in `docker.service.d/10-juicefs-ncdata.conf`: `After=/Requires=juicefs-nextcloud.service` (voorkomt dat AIO op een lege datadir start) |

De secrets staan durably (agenix-encrypted) in de repo onder `secrets/juicefs-*.age`; de plaintext op
bobadela1 wordt daaruit uitgerold (zie provisioning).

## Malandro-kant (NixOS)

- PostgreSQL 16 subscriber: db `juicefs_meta_replica`, `CREATE SUBSCRIPTION juicefs_sub` op publisher
  `192.168.2.67` / publication `juicefs_pub`.
- rustic-backup dekt de metadata **automatisch**: `pg-dump.service` draait `pg_dumpall` = incl.
  `juicefs_meta_replica`. Er staat **geen** juicefs-mount in de rustic-bronnen (geen S3→S3-recursie).

## ⚠️ Kritieke aandachtspunten

1. **RSA-key + passphrase OFFLINE bewaren** (password-manager). Deze zitten in
   `secrets/juicefs-rsa-key.age` + `secrets/juicefs-format-passphrase.age`, maar bij verlies van álle
   kopieën is de JuiceFS-data **onherstelbaar** (net als het rustic-repo-wachtwoord).
2. **Metadata-DB is kritisch.** Zonder metadata is de S3-data onleesbaar. Dekking (4-voudig):
   lokale PostgreSQL (bobadela1) → logical replication (malandro) → `pg_dumpall` in rustic →
   JuiceFS `--backup-meta` (uur-dump naar `s3://wto-s3-bucket/juicefs/meta/`).
3. **Sequences repliceren niet** via logical replication (7× `jfs_*_id_seq`). De malandro-replica is een
   *kopie*, geen naadloze promote-target. **Herstel via `juicefs load`** (zie onder), niet via de ruwe
   SQL-replica.
4. **bobadela1 flapt** (zwakke accu). De mount is non-writeback → geen verlies-venster bij een crash.

## Herstelpad (DR)

**Metadata + data terug in een lege engine:**
```bash
# 1. metadata-bron kiezen: nieuwste juicefs/meta/dump-*.json.gz uit S3, OF pg_dumpall-restore van
#    juicefs_meta_replica uit de rustic-backup.
# 2. lege PostgreSQL-db + herladen via juicefs load:
juicefs load postgres://juicefs@localhost/juicefs_meta_new < dump-YYYY-...-.json
# 3. mounten (data komt uit s3://wto-s3-bucket/juicefs/, RSA-key + passphrase nodig):
JFS_RSA_PASSPHRASE=... ACCESS_KEY=... SECRET_KEY=... \
  juicefs mount postgres://juicefs@localhost/juicefs_meta_new /mnt/restore
```

**Rollback van de migratie** (originele data staat nog onder de mount): 
```bash
sudo docker stop $(sudo docker ps -q --filter name=nextcloud-aio)
sudo systemctl stop juicefs-nextcloud.service   # unmount → originele /mnt/ncdata verschijnt weer
sudo docker start ...                            # AIO op de oude lokale datadir
```

## Operationele commando's

```bash
# mount-status
systemctl status juicefs-nextcloud.service
juicefs status postgres://juicefs@localhost/juicefs_meta      # (met META_PASSWORD in env)

# replicatie-status (op malandro)
sudo -u postgres psql -d juicefs_meta_replica -c "SELECT * FROM pg_stat_subscription;"

# Nextcloud
sudo docker exec --user www-data nextcloud-aio-nextcloud php /var/www/html/occ status
sudo docker exec --user www-data nextcloud-aio-nextcloud php /var/www/html/occ files:scan --all
```

## Migratie-resultaat (2026-09-05)

4.005 bestanden / 4,2 GiB gemigreerd van lokale disk → JuiceFS. `occ files:scan --all` →
**0 new / 0 updated / 0 removed / 0 errors** (byte-perfect). Web `nxc.toorren.net/status.php` → HTTP 200.
S3-object geverifieerd ciphertext. Publieke bucket-toegang dichtgezet (Block Public Access).

## Nog te doen (uitgesteld)

- **Reboot-test** (task 6.4): verifiëren dat na herstart de mount vóór AIO actief is. Bewust uitgesteld —
  bobadela1 flapt en komt niet altijd schoon terug; doe dit op een gepland moment aan de machine.
- **Originele datadir opruimen** (task 7.5): de oude data staat nog (shadowed) onder de mount als
  rollback. Pas opruimen ná langere verificatie: `systemctl stop juicefs-nextcloud`, de oude
  `/mnt/ncdata`-inhoud verwijderen, weer mounten. (39 G in gebruik op /dev/sda3.)
- **Full restore-round-trip test** (task 8.5): `juicefs load` in een scratch-engine + remount.
