---
# nixos-c8r0
title: 'systemd timer: dagelijks 03:00 (Persistent)'
status: completed
type: task
priority: normal
created_at: 2026-08-28T08:08:35Z
updated_at: 2026-08-28T09:07:33Z
parent: nixos-sd4i
blocked_by:
    - nixos-jznr
---

Scheduling van de backup-keten.

## Taken
- [ ] systemd.timers.rustic-backup: OnCalendar=*-*-* 03:00:00, Persistent=true (haalt gemiste run in na downtime)
- [ ] verifieer: `systemctl list-timers` toont de timer
