---
# nixos-ptwq
title: Signal poll-automation
status: completed
type: task
priority: normal
created_at: 2026-10-08T21:15:49Z
updated_at: 2026-10-08T21:29:53Z
parent: nixos-1pnf
---

time_pattern ~30s, mode single, max_exceeded silent. repeat.for_each over msgs; filter dataMessage.message bestaat + begint met / + source op whitelist; split naar command/args; router met reply=notify.signal_maria. check_config + HA-herstart. (groep 4)
