---
# nixos-xbk5
title: rustic module + repo init (opendal S3, encryptie)
status: completed
type: feature
priority: high
created_at: 2026-08-28T08:08:35Z
updated_at: 2026-08-28T09:07:32Z
parent: nixos-sd4i
blocked_by:
    - nixos-zrp5
---

NixOS-module die rustic (pkgs.rustic, nixpkgs 0.11.2) installeert en de S3-repo initialiseert.

## Taken
- [ ] modules/rustic-backup.nix aanmaken, importeren in hosts/malandro/configuration.nix
- [ ] rustic config/profile: repo = opendal:s3 (bucket, root/prefix, region), password-file = /run/secrets/rustic-repo-password
- [ ] S3-creds via EnvironmentFile = /run/secrets/rustic-s3-env
- [ ] repo `rustic init` idempotent (skip als al geïnitialiseerd)
- [ ] handmatige verificatie: `rustic snapshots` praat met de bucket

## Besluit
GEEN mountpoint-s3. Direct opendal-s3.


## Concrete invulling (2026-08-28)
- **repo**: `opendal:s3`, bucket `wto-s3-bucket`, region `eu-central-1`, root/prefix `/rustic-backup/malandro` (ARN: arn:aws:s3:::wto-s3-bucket).
- **Creds-mechanisme**: rustic-profiel (TOML, nix-store, GEEN geheim) met `access_key_id = "{{AWS_ACCESS_KEY_ID}}"` + `secret_access_key = "{{AWS_SECRET_ACCESS_KEY}}"`, en `RUSTIC_PROFILE_SUBSTITUTE_ENV=true`. Systemd-service laadt `EnvironmentFile=/run/agenix/rustic-s3-env`. Geheim komt zo NIET in nix-store/unit/ps.
- `password-file = /run/agenix/rustic-repo-password` in het profiel.
- **Verify bij impl** (rustic 0.11.2 niet op host getest):
  - exacte env-substitutie-syntax (`{{VAR}}` vs `{{ VAR }}`).
  - opendal-s3 optienamen (access_key_id / secret_access_key / region / bucket / root).
- `rustic init` idempotent; verifieer met `rustic snapshots`.


## ⚠️ CORRECTIE na lokale test (2026-08-28, rustic 0.11.2)
- Env-substitutie in profiel = **`${VAR}`** (shell-style), NIET `{{VAR}}`. `{{VAR}}` bleef letterlijk staan (getest: maakte dir `{{TESTREPO}}` aan). Gebruik `access_key_id = "${AWS_ACCESS_KEY_ID}"`.
- Vlag: `--profile-substitute-env` (of `RUSTIC_PROFILE_SUBSTITUTE_ENV=1`).
- Profiel-discovery: `-P malandro` vindt `malandro.toml` in de **current working dir** → service krijgt `WorkingDirectory=/etc/rustic`, profiel via `environment.etc."rustic/malandro.toml"`.
- opendal-s3 opties bevestigd als config-keys: bucket/region/endpoint/root/access_key_id/secret_access_key.
