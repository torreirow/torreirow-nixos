---
# nixos-w6ip
title: 'JuiceFS-volume immich: secrets, metadata-DB, mount en S3-lifecycle'
status: completed
type: task
priority: normal
created_at: 2026-11-02T21:56:32Z
updated_at: 2026-11-02T23:07:10Z
parent: nixos-ypet
---

OpenSpec add-immich-photos, tasks.md groep 1 (1.1-1.5), design D2 en D8. RSA-sleutel + wachtwoordzin via ragenx, database juicefs_immich, modules/juicefs-immich.nix (idempotente format + mount op /data/juicefs-immich), schrijf-/leestest met controle in S3 en AccessDenied buiten immich/, lifecycle-regel immich-noncurrent-180d naast de bestaande regel.


## Summary of Changes
- secrets/juicefs-immich-{passphrase,rsa-key}.age + immich-oidc.age via ragenx (waarden nooit getoond).
- modules/juicefs-immich.nix: database/rol juicefs_immich (peer via identMap, pg_hba met mkOverride 10 naast docseal), idempotente juicefs-immich-format, mount juicefs-immich op /data/juicefs-immich (wacht tot mountpoint).
- Volume immich: aes256gcm-rsa, TrashDays 30, data onder s3://wto-s3-bucket/immich/. Schrijftest: 3 MB → versleuteld blok in S3, terug gelezen.
- AWS: lifecycle immich-noncurrent-180d naast juicefs-noncurrent-180d.
