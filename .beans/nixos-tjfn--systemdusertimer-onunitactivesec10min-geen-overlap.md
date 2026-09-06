---
# nixos-tjfn
title: systemd.user.timer OnUnitActiveSec=10min (geen overlap)
status: completed
type: task
priority: normal
created_at: 2026-08-31T10:50:05Z
updated_at: 2026-08-31T10:59:54Z
parent: nixos-3es6
---

systemd.user.timer per sync-paar: OnActiveSec=2min (eerste run) + OnUnitActiveSec=<interval> (default 10min, geen overlap). WantedBy=timers.target. Geverifieerd via extendModules eval.
