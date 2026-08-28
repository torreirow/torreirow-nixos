---
# nixos-97nl
title: Restore-test + documentatie
status: completed
type: task
priority: normal
created_at: 2026-08-28T08:08:35Z
updated_at: 2026-08-28T09:07:33Z
parent: nixos-sd4i
blocked_by:
    - nixos-jznr
    - nixos-c8r0
---

Bewijzen dat de backup terug te zetten is + vastleggen in CLAUDE.md.

## Taken
- [ ] `rustic restore` van een snapshot naar een tmp-dir; controleer bestanden
- [ ] DB-restore droog testen: pg-dump/mysqldump/vaultwarden.sqlite terugzetten op een test-DB
- [ ] restore-procedure documenteren in CLAUDE.md (repo-URL, waar secrets staan, herstelstappen)
- [ ] PORTS.md n.v.t.; noteer wél dat mountpoint-s3 bewust NIET gebruikt wordt en waarom
