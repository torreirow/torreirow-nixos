---
# nixos-zqtb
title: 'pg-dump.service: pg_dumpall van PostgreSQL 16'
status: completed
type: task
priority: high
created_at: 2026-08-28T08:08:35Z
updated_at: 2026-08-28T09:07:32Z
parent: nixos-sd4i
---

Losse systemd-service die alle 12 PostgreSQL-DBs logisch dumpt (roles/globals incl.).

## Context
- Host-service, postgresql_16, dataDir /data/external/postgresql/16, port 5432.
- DBs: flare chhoto_url opsknight paperless crowdsec postgres gitea vikunja memos prometheus documenso docseal.

## Taken
- [ ] systemd.services.pg-dump: `pg_dumpall` (als postgres-user) -> /var/backup/db/pg-all.sql (of .sql.zst)
- [ ] staging-dir /var/backup/db bestaat, mode 0700, owner root
- [ ] OnFailure -> notificatie
- [ ] los draaibaar: `systemctl start pg-dump` werkt onafhankelijk
