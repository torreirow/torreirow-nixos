---
# nixos-3o4y
title: 'linny-web module: optionele SSH-deploy-key-auth (gitSshKeyFile) + assertion exactly-one'
status: completed
type: task
priority: normal
created_at: 2026-09-04T13:43:00Z
updated_at: 2026-09-04T13:45:12Z
parent: nixos-9596
---

In linny-web-theme: gitTokenFile en gitSshKeyFile beide nullOr, assertion precies-een. SSH-modus: GIT_SSH_COMMAND met -i key, IdentitiesOnly, known_hosts in stateDir; git_auth zonder credential-helper. README/optietabel + CHANGELOG + flake-check uitbreiden.
