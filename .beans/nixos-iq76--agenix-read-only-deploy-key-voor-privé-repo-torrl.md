---
# nixos-iq76
title: 'agenix: read-only deploy key voor privé-repo torrlinny'
status: completed
type: task
priority: normal
created_at: 2026-09-03T05:21:29Z
updated_at: 2026-09-03T06:21:03Z
parent: nixos-anvf
---

Read-only SSH **deploy key** zodat de build-service de PRIVÉ repo `torreirow/torrlinny` kan clonen/pullen op malandro.

## Todo
- [ ] SSH-keypair (ed25519) genereren; **public** key als *read-only deploy key* op de GitHub-repo torrlinny zetten
- [ ] **private** key als agenix-secret: `secrets/torrlinny-deploy-key.age`, `path = /run/agenix/torrlinny-deploy-key`, owner = build-user, mode 0400
- [ ] `GIT_SSH_COMMAND` / ssh-config voor github.com met `IdentitiesOnly yes` + deze key

## Notitie
Pad-conventie `/run/agenix/…` (malandro), NIET /run/secrets. De submodule-themes (PaperMod, geekdoc) zijn publiek (https) → alleen de main-repo heeft de key nodig.



## Summary of Changes
ed25519 read-only deploy key op github.com/torreirow/torrlinny (id 162141965); private key als agenix-secret `secrets/torrlinny-deploy-key.age` + recipient in secrets.nix. Clone-auth end-to-end getest.
