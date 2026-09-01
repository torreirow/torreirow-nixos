---
# nixos-o1m6
title: 'mariadb-dump.service: mysqldump --all-databases'
status: completed
type: task
priority: high
created_at: 2026-08-28T08:08:35Z
updated_at: 2026-08-28T09:07:32Z
parent: nixos-sd4i
---

Losse systemd-service die alle MariaDB app-DBs consistent dumpt.

## Context
- Host-service (mysql.service), bind 0.0.0.0:3306.
- App-DBs: bookstack castopod invoiceplane vikunja wallos (system-DBs mogen mee).

## Taken
- [ ] systemd.services.mariadb-dump: `mysqldump --all-databases --single-transaction --routines --triggers --events` -> /var/backup/db/mysql-all.sql
- [ ] `--single-transaction` voor consistente snapshot zonder lange locks
- [ ] auth via socket/root of dedicated backup-user
- [ ] OnFailure -> notificatie; los draaibaar
