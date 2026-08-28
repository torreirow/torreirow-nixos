# Tasks — add-rustic-s3-backup

## 1. Secrets (bean nixos-zrp5)
- [x] 1.1 `secrets/secrets.nix`: entries voor `rustic-s3-env.age` + `rustic-repo-password.age` (reeds toegevoegd)
- [x] 1.2 `.age`-files aangemaakt door gebruiker (reeds gedaan)
- [x] 1.3 `age.secrets.*` declaraties in module met `path = /run/agenix/...`, mode 0400
- [x] 1.4 Extra agenix-paths voor Telegram token/chat (hergebruik monitoring-secrets)

## 2. Dump-services
- [x] 2.1 `pg-dump.service` — `pg_dumpall` via `runuser -u postgres`, zstd → `/var/backup/db/pg-all.sql.zst` (bean nixos-zqtb)
- [x] 2.2 `mariadb-dump.service` — `mysqldump --all-databases --single-transaction` als root/socket, zstd (bean nixos-o1m6)
- [x] 2.3 `vaultwarden-dump.service` — `sqlite3 .backup` → `/var/backup/db/vaultwarden.sqlite3` (bean nixos-kzlg)
- [x] 2.4 Staging-dir `/var/backup/db` via tmpfiles (0700 root)
- [x] 2.5 Elke dump los draaibaar + eigen `OnFailure`

## 3. rustic module + repo (bean nixos-xbk5)
- [x] 3.1 `modules/rustic-backup.nix` met `pkgs.rustic`
- [x] 3.2 Profiel `/etc/rustic/malandro.toml` (opendal:s3, bucket/region/endpoint/root, `${AWS_*}`-placeholders, password-file)
- [x] 3.3 Import in `hosts/malandro/configuration.nix`
- [x] 3.4 Idempotente init (repoinfo-check → init)

## 4. Backup-service + retentie (bean nixos-jznr)
- [x] 4.1 `rustic-backup.service` — Wants/After de 3 dumps, EnvironmentFile + `--profile-substitute-env`
- [x] 4.2 Manifest: sources over twee roots + DB-dumps
- [x] 4.3 Excludes via `!`-globs (live VW-sqlite, caches, paperless consume/export)
- [x] 4.4 `forget --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --prune`

## 5. Scheduling (bean nixos-c8r0)
- [x] 5.1 `rustic-backup.timer` — `OnCalendar=*-*-* 03:00:00`, `Persistent=true`

## 6. Notificatie (bean nixos-ure2)
- [x] 6.1 Template-unit `rustic-notify@` → Telegram sendMessage
- [x] 6.2 `OnFailure=` gekoppeld aan alle vier services

## 7. Verificatie & docs (bean nixos-97nl)
- [x] 7.1 `nixos-rebuild dry-build`/eval schoon
- [x] 7.2 Dump-services handmatig draaien; output in `/var/backup/db` controleren
- [x] 7.3 `rustic init` + `rustic backup` + `rustic snapshots` tegen S3 (handmatige trigger)
- [x] 7.4 Restore-test naar tmp-dir; DB-dumps droog terugzetten
- [x] 7.5 Restore-procedure documenteren in CLAUDE.md; mountpoint-s3 bewust NIET gebruikt noteren
