---
# nixos-sd4i
title: Rustic S3 backup (Vaultwarden + databases + /data)
status: completed
type: epic
priority: high
created_at: 2026-08-28T08:08:34Z
updated_at: 2026-08-28T09:07:33Z
---

Thematic container. Automated, encrypted, incremental off-site backup naar AWS S3 met rustic (rustic-rs), plus disaster-recovery dumps van alle databases.

## Doel
In geval van nood álles kunnen terugzetten: alle app-state van de docker-containers en een schone restore van PostgreSQL, MariaDB en de Vaultwarden-SQLite.

## Architectuur-besluiten (uit /opsx:explore)
- **rustic schrijft DIRECT naar S3** via de opendal-s3 backend. GEEN mountpoint-s3 / FUSE — die kan geen rename/lock/atomic-replace en zou de repo corrumperen. `/data/s3` wordt dus GEEN echte mount, maar een repo-URL.
- **Databases logisch dumpen, niet raw file-copyen.** Aparte, los-draaibare dump-services (pg / mariadb / vaultwarden) schrijven naar staging-dir `/var/backup/db/`; rustic pakt die dumps mee.
- **Bronnen liggen over twee roots**: `/var/lib/*` (HA, Zigbee2MQTT, wg-easy, Baikal, signal-cli, mosquitto, mmdl, vaultwarden) EN gecureerd `/data/external/*`. Alleen `/data/external` zou de helft missen.
- **AWS-auth**: access key + secret access key (via agenix).
- **Retentie**: keep-daily 7, keep-weekly 4, keep-monthly 3.
- **Scheduling**: systemd timer, dagelijks 03:00, Persistent=true.

## Backup-manifest
INCLUDE file-level:
- /var/lib/{homeassistant,vaultwarden,zigbee2mqtt,signal-cli,wg-easy,baikal,mmdl,mosquitto}
- /data/external/{docseal,erugo,wallos,invoiceplane-docker,pihole,castopod}  (castopod = media; DB via mariadb-dump)
- /data/external/dockerlibs/volumes  (named/anon docker volumes: redis, mqtt data)
- /data/external/tmp/paperless  (media + data)
- /var/backup/db/  (de DB-dumps)

EXCLUDE:
- /data/external/postgresql  (raw PG -> pg_dumpall i.p.v.)
- live /var/lib/vaultwarden/db.sqlite3{,-wal,-shm}  (-> sqlite .backup i.p.v.)
- prometheus (metrics, churn), registry-mirror (cache), dockerlib (oud data-root)
- lost+found, docker image/overlay layers
- crowdsec, nextcloud (bewust NIET meenemen, besluit 2026-08-28)
- invoiceplane / invoiceplane-old / invoiceplane-docker-docker (rommel; niet live gemount)

## Ship
Model A: één OpenSpec change `add-rustic-s3-backup` dekt de hele epic. Child-beans spiegelen de fases voor tracking. `/cas:1shotepic` op deze epic -> OpenSpec proposal + implementatie.


## S3-target (concreet, 2026-08-28)
- bucket `wto-s3-bucket`, region `eu-central-1`, root/prefix `/rustic-backup/malandro` (ARN arn:aws:s3:::wto-s3-bucket).
- Creds via agenix env-file (`/run/agenix/rustic-s3-env`) + `RUSTIC_PROFILE_SUBSTITUTE_ENV`; repo-pw via `/run/agenix/rustic-repo-password`. Default-pad = `/run/agenix/` (malandro-conventie), NIET /run/secrets.
- Least-privilege IAM-user beperkt tot deze bucket (in AWS aan te maken, buiten repo-scope).


## IAM (concreet, 2026-08-28)
- IAM-user `hasio`. Policy dekt ListBucket/PutObject/GetObject/AbortMultipartUpload/DeleteObject — ✅ DeleteObject toegevoegd (2026-08-28), prune/retentie gedekt.
