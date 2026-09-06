---
# nixos-jx75
title: systemd.user.service (oneshot) wrapper rond nextcloudcmd
status: completed
type: task
priority: normal
created_at: 2026-08-31T10:50:05Z
updated_at: 2026-08-31T10:59:54Z
parent: nixos-3es6
---

Oneshot systemd.user.service per sync-paar. ExecStart=nextcloudcmd --non-interactive --silent [--trust] [--path R] --confdir S <local> <url> via escapeShellArgs. EnvironmentFile=-<credentialsFile> (optioneel-prefix). ExecStartPre valideert credentials + mkdir -p local/state met nette foutmelding.
