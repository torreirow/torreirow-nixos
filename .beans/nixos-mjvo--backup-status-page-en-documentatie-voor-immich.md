---
# nixos-mjvo
title: Backup, status-page en documentatie voor Immich
status: completed
type: task
priority: normal
created_at: 2026-11-02T21:56:32Z
updated_at: 2026-11-02T23:07:11Z
parent: nixos-ypet
blocked_by:
    - nixos-cv87
---

OpenSpec add-immich-photos, tasks.md groep 4 (4.1-4.4), design D7. juicefs dump van juicefs_immich in modules/rustic-backup.nix, status-page nativeServices, PORTS.md, docs/immich.md + CLAUDE.md-indexregel, CHANGELOG, geheugenmeting. Daarna de change archiveren en committen.


## Summary of Changes
- rustic-backup: juicefs-immich-meta-dump.service → /var/backup/db/juicefs-immich-meta-dump.json; backup-run success, pg-all bevat immich en juicefs_immich.
- status-page: immich-server, redis-immich, juicefs-immich (gezond). PORTS.md 2283 + vhost-regel.
- docs/immich.md, CLAUDE.md-indexregel, CHANGELOG. Geheugen bij start: immich ±700 MB, 4,0 GB vrij.
- OpenSpec add-immich-photos gearchiveerd als 2026-11-03-add-immich-photos, spec immich-photos.
