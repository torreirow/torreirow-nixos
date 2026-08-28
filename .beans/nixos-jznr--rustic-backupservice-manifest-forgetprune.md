---
# nixos-jznr
title: 'rustic-backup.service: manifest + forget/prune'
status: completed
type: feature
priority: high
created_at: 2026-08-28T08:08:35Z
updated_at: 2026-08-28T09:07:33Z
parent: nixos-sd4i
blocked_by:
    - nixos-xbk5
    - nixos-zqtb
    - nixos-o1m6
    - nixos-kzlg
---

De hoofd-backup-service: draait ná de dumps, backupt het volledige manifest en pruned volgens retentie.

## Ordering
- Wants= + After= pg-dump, mariadb-dump, vaultwarden-dump (dumps eerst, dan rustic).

## Taken
- [ ] systemd.services.rustic-backup met de include/exclude manifest uit de epic
- [ ] `rustic backup` van /var/backup/db + /var/lib/* + gecureerd /data/external/*
- [ ] excludes: postgresql (raw), prometheus, registry-mirror, dockerlib, lost+found, live vw db, image-layers, invoiceplane-rommel, crowdsec, nextcloud
- [ ] `rustic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --prune`
- [ ] OnFailure -> notificatie


## Prune-vereiste (2026-08-28)
- `rustic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --prune` vereist **`s3:DeleteObject`** op IAM-user `hasio` — ✅ toegevoegd (2026-08-28), prune kan verlopen packs verwijderen.


## ⚠️ Glob-semantiek na lokale test (2026-08-28)
- rustic `--glob`: **`!pattern` = EXCLUDE**, plain pattern = restrictieve INCLUDE. Gebruik alléén `!`-excludes; al het overige wordt default meegenomen.
- Within-source excludes nodig: live VW-sqlite (`!/var/lib/vaultwarden/db.sqlite3*`, -wal/-shm), icon_cache, _temp; paperless consume/export. De overige /data/external-dirs (postgresql/prometheus/crowdsec/nextcloud/registry-mirror/dockerlib) staan simpelweg NIET in de sources → automatisch uitgesloten.
