---
# nixos-zrp5
title: 'agenix secrets: rustic repo-password + S3 credentials'
status: completed
type: task
priority: high
created_at: 2026-08-28T08:08:35Z
updated_at: 2026-08-28T09:07:32Z
parent: nixos-sd4i
---

Twee nieuwe agenix secrets aanmaken en aan malandro koppelen.

## Taken
- [ ] secrets/rustic-repo-password.age  (encryptie-wachtwoord van de rustic repo)
- [ ] secrets/rustic-s3-env.age  (AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY, evt. AWS_REGION / bucket)
- [ ] secrets.nix bijwerken met beide files
- [ ] age.secrets.* in malandro met expliciet `path = "/run/secrets/..."` (les uit CLAUDE.md: zonder path geen symlink), owner/mode 0400
- [ ] rebuild: secrets verschijnen in /run/secrets/

## Let op
- Expliciet `path` is verplicht als een service/config het secret via bestand leest.


## Concrete invulling (2026-08-28)
- **Default = /run/agenix/**, NIET /run/secrets (dat was de lobos/msmtp-context). Malandro-conventie volgt docseal/chhoto.
- Twee secrets:
  - `secrets/rustic-s3-env.age` → env-file met `AWS_ACCESS_KEY_ID=…` en `AWS_SECRET_ACCESS_KEY=…` (path `/run/agenix/rustic-s3-env`).
  - `secrets/rustic-repo-password.age` → 1 regel, repo-encryptie-wachtwoord (path `/run/agenix/rustic-repo-password`, mode 0400).
- **Least-privilege IAM (eis)**: dedicated IAM-user/key, policy beperkt tot `arn:aws:s3:::wto-s3-bucket` + `/*` (PutObject/GetObject/ListBucket/DeleteObject). NIET de algemene technative-creds hergebruiken.
- secrets.nix bijwerken met beide files.


## IAM-user (concreet, 2026-08-28)
- Bestaande IAM-user **`hasio`** levert de key/secret.
- ✅ **`s3:DeleteObject` TOEGEVOEGD (2026-08-28)** aan ObjectLevelPermissions → `rustic forget --prune` (retentie 7/4/3) gedekt.
- Optioneel (safety): `s3:ListMultipartUploadParts` + `s3:ListBucketMultipartUploads` voor afgebroken multipart-uploads.
- Optioneel (hardening): Resource inperken van `wto-s3-bucket/*` naar `wto-s3-bucket/rustic-backup/malandro/*`.
- Policy dekt nu: ListBucket, PutObject, GetObject, AbortMultipartUpload, DeleteObject.


## Handmatige .age-aanmaak (door user; NIET door agent — vereist private key)
1. `secrets/secrets.nix` uitbreiden (patroon = alle andere entries):
   ```nix
   "rustic-s3-env.age".publicKeys        = users ++ [ wtoorren_workstation malandro_workstation ];
   "rustic-repo-password.age".publicKeys = users ++ [ wtoorren_workstation malandro_workstation ];
   ```
2. In `secrets/`: `agenix -e rustic-s3-env.age` → inhoud:
   ```
   AWS_ACCESS_KEY_ID=...        (IAM-user hasio)
   AWS_SECRET_ACCESS_KEY=...
   ```
3. `agenix -e rustic-repo-password.age` → 1 regel, bv. `openssl rand -base64 32`.
- Recipients: users + wtoorren_workstation + malandro_workstation (malandro moet kunnen decrypten).
- ⚠️ repo-wachtwoord OOK buiten de backup bewaren (password-manager + offline) — anders bij totale ramp niet te decrypten. NIET uitsluitend in Vaultwarden (dat wordt door rustic geback-upt = circulair).
- /run/agenix/rustic-s3-env en /run/agenix/rustic-repo-password zijn runtime-output van agenix; niet handmatig plaatsen.
