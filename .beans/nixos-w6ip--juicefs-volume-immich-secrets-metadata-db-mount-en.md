---
# nixos-w6ip
title: 'JuiceFS-volume immich: secrets, metadata-DB, mount en S3-lifecycle'
status: todo
type: task
priority: normal
created_at: 2026-11-02T21:56:32Z
updated_at: 2026-11-02T21:56:47Z
parent: nixos-ypet
---

OpenSpec add-immich-photos, tasks.md groep 1 (1.1-1.5), design D2 en D8. RSA-sleutel + wachtwoordzin via ragenx, database juicefs_immich_meta, modules/juicefs-immich.nix (idempotente format + mount op /data/juicefs-immich), schrijf-/leestest met controle in S3 en AccessDenied buiten immich/, lifecycle-regel immich-noncurrent-180d naast de bestaande regel.
