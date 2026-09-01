---
# nixos-kzlg
title: 'vaultwarden-dump.service: sqlite .backup snapshot'
status: completed
type: task
priority: high
created_at: 2026-08-28T08:08:35Z
updated_at: 2026-08-28T09:07:32Z
parent: nixos-sd4i
---

Losse systemd-service die een consistent snapshot maakt van de Vaultwarden-SQLite (WAL-mode).

## Waarom
Rauw db.sqlite3 kopiëren is niet-atomair (commits zitten in -wal, niet gecheckpoint) -> torn read. `.backup` gebruikt de online-backup API: consistent, zonder downtime.

## Taken
- [ ] systemd.services.vaultwarden-dump: `sqlite3 /var/lib/vaultwarden/db.sqlite3 ".backup /var/backup/db/vaultwarden.sqlite3"`
- [ ] file-level backup van /var/lib/vaultwarden pakt attachments/sends/rsa_key.pem/config.json apart
- [ ] live db.sqlite3{,-wal,-shm} EXCLUDEN uit de file-backup
- [ ] los draaibaar; OnFailure -> notificatie
