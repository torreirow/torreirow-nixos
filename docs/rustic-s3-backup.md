# Rustic S3 backup (Vaultwarden + DBs + /data)

Dagelijkse versleutelde off-site backup naar S3, dump-services, secrets en handmatige commando's. Restore-test: zie docs/vaultwarden-restore-test.md.

> Verplaatst uit CLAUDE.md (Huidige Status) om de sessie-context slank te houden.

### Sessie 2026-08-28 - Rustic S3 backup (Vaultwarden + DBs + /data) - OPGELOST

**Doel:** Dagelijkse, versleutelde, incrementele off-site backup naar AWS S3 met
[rustic](https://github.com/rustic-rs/rustic), plus disaster-recovery dumps van PostgreSQL,
MariaDB en de Vaultwarden-SQLite. Zie OpenSpec change `add-rustic-s3-backup` (gearchiveerd) en
Beans-epic `nixos-sd4i`.

**Opzet — module `modules/rustic-backup.nix` (import in `hosts/malandro/configuration.nix`):**
- **rustic praat DIRECT met S3** via de opendal-s3 backend — **GEEN mountpoint-s3/FUSE**. FUSE kan
  geen rename/lock/atomic-replace en zou de rustic-repo corrumperen. `/data/s3` is dus géén mount
  geworden maar een repo-URL. Repo: `s3://wto-s3-bucket/rustic-backup/malandro` (region `eu-central-1`).
- **3 los-draaibare dump-services** (oneshot, als root) schrijven naar `/var/backup/db/`:
  - `pg-dump.service` → `runuser -u postgres -- pg_dumpall --clean --if-exists` | zstd → `pg-all.sql.zst`
  - `mariadb-dump.service` → `mysqldump --all-databases --single-transaction` (root/unix-socket) | zstd
  - `vaultwarden-dump.service` → `sqlite3 db.sqlite3 ".backup ..."` (online-backup, geen downtime)
- **`rustic-backup.service`** (oneshot, Wants+After de 3 dumps) → `rustic backup` van het manifest +
  `rustic forget --filter-host malandro --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --prune`.
- **`rustic-backup.timer`** — dagelijks 03:00, `Persistent=true`.
- **Faal-notificatie**: template-unit `rustic-notify@` → **Signal** via de lokale signal-cli REST API
  (`http://127.0.0.1:8088/v2/send`, jq bouwt de JSON). Afzender `<signal-afzender>`, ontvanger `<signal-ontvanger>`
  (zelfde als HA `signal_maria`). Op `OnFailure=` van alle vier services. Best-effort (`|| true`); geen
  agenix-secret nodig (nummers zijn niet geheim, staan plain in de module — net als in de HA-config).
- **Manifest (twee roots!):** `/var/lib/{homeassistant,vaultwarden,zigbee2mqtt,signal-cli,wg-easy,baikal,
  mmdl,mosquitto}` + `/data/external/{docseal,erugo,wallos,invoiceplane-docker,pihole,castopod,
  dockerlibs/volumes,tmp/paperless}` + `/var/backup/db`. Excludes via `!`-globs: live VW-sqlite
  (`db.sqlite3{,-wal,-shm}`), caches, paperless consume/export. Overige /data/external-dirs
  (postgresql/prometheus/crowdsec/nextcloud/registry-mirror/dockerlib) staan simpelweg niet in de sources.

**Secrets (agenix, pad `/run/agenix/…` — malandro-conventie):**
- `rustic-s3-env.age` → env-file met `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` (IAM-user `hasio`),
  geladen via `EnvironmentFile=`.
- `rustic-repo-password.age` → repo-encryptie-wachtwoord (password-file in het profiel).
- ⚠️ **Repo-wachtwoord OOK buiten de backup bewaren** (password-manager + offline). Niet uitsluitend in
  Vaultwarden — dat wordt door rustic geback-upt (circulair). Bij verlies is de repo onherstelbaar.

**Belangrijke lessen (lokaal getest met rustic 0.11.2):**
- **Env-substitutie = `${VAR}`**, NIET `{{VAR}}` (die bleef letterlijk staan). Vlag `--profile-substitute-env`.
  Zo blijven de echte keys uit de nix-store/unit/`ps`: het profiel `/etc/rustic/malandro.toml` bevat
  alleen `${AWS_*}`-placeholders.
- **`rustic --glob`: `!pattern` = EXCLUDE**, plain pattern = restrictieve INCLUDE. Gebruik alléén `!`-excludes.
- **Profiel-discovery**: `-P malandro` vindt `malandro.toml` in de working directory → `WorkingDirectory=/etc/rustic`.
- **`rustic forget` accepteert géén `--host`** (backup wel); gebruik `--filter-host`.
- IAM-policy `hasio` heeft `s3:DeleteObject` nodig voor prune (toegevoegd).

**Geverifieerd:** switch schoon; 3 dumps produceren valide output (pg cluster-dump, MariaDB-dump,
sqlite `integrity_check: ok`); volledige backup → S3 (snapshot 6820 files, 2.5 G), 2e run incrementeel
(dedup), forget/prune correct; **restore-round-trip** van de VW-dump uit S3 → `integrity_check: ok`.

**Handmatige commando's:**
```bash
sudo systemctl start pg-dump.service            # losse dump testen
sudo systemctl start rustic-backup.service      # volledige backup + prune
# rustic direct (met creds + profiel):
sudo bash -c 'cd /etc/rustic && set -a && . /run/agenix/rustic-s3-env && set +a && \
  '"$(nix build --no-link --print-out-paths nixpkgs#rustic)"'/bin/rustic -P malandro --profile-substitute-env snapshots'
# restore: ... rustic -P malandro --profile-substitute-env restore latest:/PATH /doel
```

**Status:** ✅ Live. Timer draait dagelijks 03:00; eerste backups + restore-test geslaagd.

**Restore-test (herhaalbaar):** `~/bin/vaultwarden-restoretest.sh` (bron: `home/module/vaultwarden-restore-test/`,
via home-manager; OpenSpec change `add-vaultwarden-restore-test`). Non-destructief:
```bash
vaultwarden-restoretest.sh                # basis: restore→reassemble→wegwerp-container :8099→/alive+counts
vaultwarden-restoretest.sh --rbw          # + geïsoleerde rbw-login (master-pw + TOTP) → bewijst decrypt
vaultwarden-restoretest.sh --snapshot ID  # specifieke backup
vaultwarden-restoretest.sh --keep         # container laten staan om te snuffelen
vaultwarden-restoretest.sh --destroy      # opruimen
```
`--rbw` gebruikt een strikt geïsoleerde rbw (XDG-override, eigen agent) → raakt de echte rbw-config
(`~/.config/rbw`, vw.toorren.net) niet aan. 2FA blijft staan, dus TOTP-code invoeren.
