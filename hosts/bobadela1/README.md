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

## Dagelijkse shutdown 23:00

`nightly-shutdown.service` (oneshot → `systemctl poweroff`) + `nightly-shutdown.timer`
(`OnCalendar=*-*-* 23:00:00`) zetten de machine elke avond om 23:00 uit. De unit-bestanden staan
in deze map als bron; ze worden imperatief uitgerold naar `/etc/systemd/system/` op bobadela1.

- **`Persistent=false`** bewust: bobadela1 flapt (zwakke accu). Met `Persistent=true` zou een gemiste
  23:00 bij de eerstvolgende boot alsnog een directe poweroff triggeren.

```bash
# uitrollen / bijwerken (vanaf een host met ssh bobadela1):
scp hosts/bobadela1/nightly-shutdown.{service,timer} bobadela1:/tmp/
ssh bobadela1 'sudo mv /tmp/nightly-shutdown.{service,timer} /etc/systemd/system/ && \
  sudo systemctl daemon-reload && sudo systemctl enable --now nightly-shutdown.timer'

# bediening:
ssh bobadela1 'systemctl list-timers nightly-shutdown.timer'     # volgende run
ssh bobadela1 'sudo systemctl disable --now nightly-shutdown.timer'  # tijdelijk uit
```

## Dagelijkse AIO-update 12:00 (lokale tijd)

AIO's ingebouwde "daily backup + automatic updates" plant **altijd in UTC** en hangt aan een
borg-backuplocatie. Daarom een eigen timer op bobadela1 (Europe/Amsterdam, schuift mee met
zomer-/wintertijd), alleen updates, géén borg-backup.

**Bewust geen backup van de Nextcloud-DB/`config.php`** (besluit 2026-10-22): Nextcloud dient alleen
als bestands-backup voor 3 users. De bestanden staan op JuiceFS (S3) en de JuiceFS-metadata is
4-voudig gedekt; accounts/shares zijn bij verlies met de hand opnieuw te maken en de bestanden
daarna opnieuw te scannen (`occ files:scan --all`). Verwijderde bestanden zijn terug te halen via
Nextcloud's eigen prullenbak/versies (`files_trashbin`/`files_versions`, staan ook op JuiceFS).

**Restrisico:** alles met schrijfrechten op de live data (gecompromitteerde Nextcloud-container,
root op bobadela1, de AWS-keys) kan óók prullenbak/versies wissen. Vangnetten daaronder (stand
2026-10-23):

- JuiceFS-trash: `trash-days` 1 → **30** (2026-10-23, `juicefs config … --trash-days 30`).
- S3-versioning op `wto-s3-bucket`: **Enabled**, **geen lifecycle** → oude versies blijven
  onbeperkt staan. IAM-user `juicefs-nextcloud` (policy `juicefs-nextcloud-s3`, gedeeld door
  bobadela1 én malandro) mag alleen `Get/Put/DeleteObject` + `ListBucket` op `juicefs/*`: géén
  `DeleteObjectVersion`, `PutBucketVersioning` of `PutLifecycleConfiguration`. Een gelekte key
  kan dus alleen delete-markers zetten; de oude versies blijven terug te halen.
  Meting 2026-10-23: 15,1 GB / 4.472 noncurrent versies + 4.473 delete-markers, vrijwel
  allemaal eenmalig door de migratie OneDrive → Nextcloud (sept/okt); groei daarna verwacht laag.
- Open: lifecycle (noncurrent na N dagen weg) en een aparte read-only key voor malandro.

Omvang 2026-10-22 (uit `juicefs_meta_replica`): **~47 GB / 16.103 bestanden** — mtoorren 22 GB,
wtoorren 18 GB, hjtoorren 5,5 GB; prullenbak + versies samen < 15 MB.

- `nextcloud-aio-update.timer` (`OnCalendar=*-*-* 12:00:00`, `Persistent=false`, zelfde reden als de
  shutdown) → `nextcloud-aio-update.service` → `/usr/local/sbin/nextcloud-aio-update`
  (bron: `nextcloud-aio-update.sh`).
- Het script draait `docker exec --env AUTOMATIC_UPDATES=1 --env DAILY_BACKUP=0
  nextcloud-aio-mastercontainer /daily-backup.sh`. Werkt dat de mastercontainer bij, dan sneuvelt de
  exec; het script ziet een gewijzigde `StartedAt`, wacht op healthy en draait een tweede keer (zoals
  AIO voorschrijft). Zonder mastercontainer-update: één run → één stop/start (~2–5 min downtime).
- Aanleiding: PHP2Shell (CVE-2026-109618/9, 21 okt 2026) — de images bleken sinds 6 aug niet
  bijgewerkt. Eerste testrun 2026-10-22: geslaagd, Nextcloud 34.0.5 / PHP 8.4.27.

```bash
# uitrollen / bijwerken:
scp hosts/bobadela1/nextcloud-aio-update.{sh,service,timer} bobadela1:/tmp/
ssh bobadela1 'sudo install -m0755 /tmp/nextcloud-aio-update.sh /usr/local/sbin/nextcloud-aio-update && \
  sudo mv /tmp/nextcloud-aio-update.{service,timer} /etc/systemd/system/ && \
  sudo systemctl daemon-reload && sudo systemctl enable --now nextcloud-aio-update.timer'

# bediening:
ssh bobadela1 'sudo systemctl start nextcloud-aio-update.service'          # nu updaten
ssh bobadela1 'journalctl -u nextcloud-aio-update.service -n 30'           # log laatste run
```

## Dagelijkse ochtend-wake 09:00 (vanaf malandro)

Complement van de 23:00-shutdown: malandro wekt bobadela1 elke ochtend 09:00 via **Wake-on-LAN**.
Beheerd in NixOS (`modules/wake-bobadela1/`, import in `hosts/malandro/configuration.nix`) — dus in
tegenstelling tot de shutdown-units imperatief-op-bobadela1 leeft deze kant volledig in de repo.

- **`wake-bobadela1.timer`** (`OnCalendar=*-*-* 09:00`, `Persistent=true`) → **`wake-bobadela1.service`**
  (oneshot, root). Draait het gedeelde script `modules/wake-bobadela1/wake-bobadela1.py`.
- **Doorzetten:** 30 min lang proberen, WoL-burst elke 5 min (`--wait 1800 --burst 300`).
- **Succes = Nextcloud, niet alleen ping:** pas klaar als `http://192.168.2.67:11000/status.php` HTTP 200
  geeft met `installed:true` + `maintenance:false` (`--check-nextcloud`). Idempotent: al gezond → geen packet.
- **Signal bij falen** (`--notify`, via signal-cli REST `:8088`, zelfde afzender/ontvanger als
  `rustic-notify@`): **A** geen ping na 30 min · **B** host op maar Nextcloud niet gezond.
- **Handmatig wekken:** `wake-bobadela1` (op malandro; `~/bin`-symlink via home-manager, zelfde bron).

```bash
# op malandro:
systemctl list-timers wake-bobadela1.timer          # volgende run (09:00)
sudo systemctl start wake-bobadela1.service          # nu draaien (service-modus + Signal)
wake-bobadela1 --check-nextcloud                     # handmatig, snel, zonder Signal
sudo systemctl disable --now wake-bobadela1.timer    # tijdelijk uit
```

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

## Read-only mount op malandro (`/data/juicefs-nextcloud`)

Malandro mount HETZELFDE volume **read-only** tegen bobadela1's live metadata, zodat de
Nextcloud-bestanden daar leesbaar zijn (bv. voor backup/processing) zonder wijzigingsrisico.

- **NixOS-module:** `modules/juicefs-nextcloud-mount.nix` → systemd-service `juicefs-nextcloud-ro`
  (mount `/data/juicefs-nextcloud`, `--read-only -o allow_other`, cache `/var/cache/juicefs-nextcloud`,
  `Restart=on-failure`). Creds uit agenix: `secrets/juicefs-malandro-env.age`
  (ACCESS_KEY/SECRET_KEY/META_PASSWORD/JFS_RSA_PASSPHRASE).
- **pg_hba (bobadela1):** extra regel `host juicefs_meta juicefs 192.168.2.52/32 scram-sha-256`
  zodat malandro als `juicefs`-rol de metadata mag lezen.
- **Wheel-toegang:** de volume-root is `chgrp 1` (= wheel op malandro) + mode `0750`, dus wheel-leden
  kunnen lezen zonder sudo, zónder de datadir wereld-leesbaar te maken. (Op bobadela1 toont de groep
  cosmetisch gid 1.) Gezet via bobadela1's RW-mount: `sudo chgrp 1 /mnt/ncdata && sudo chmod 0750 /mnt/ncdata`.
- **Afhankelijkheid:** deze mount hangt aan bobadela1 (postgres) + de LAN; valt bobadela1 weg dan stalt
  de mount en herstelt `Restart=on-failure` zodra bobadela1 er weer is.

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
