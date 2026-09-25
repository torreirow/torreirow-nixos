---
# nixos-ce9f
title: RW deploy key + bidirectionele git-sync van het linny-mcp-corpus
status: todo
type: task
priority: normal
created_at: 2026-09-25T07:44:20Z
updated_at: 2026-09-25T07:45:40Z
parent: nixos-m0vn
blocked_by:
    - nixos-dqs2
---

Het corpus bidirectioneel synchroon houden met `github.com/torreirow/torrlinny`, zodat
agent-notities terugkomen op GitHub en notities van lobos hier binnenkomen.

## Waarom een aparte sleutel
`torrlinny-deploy-key` (agenix) is **read-only** en van de Hugo-build. Die moet read-only blijven:
de Hugo-build hoort nooit te kunnen pushen. Dus een **tweede, read/write** deploy key voor
linny-mcp. Per-repo deploy key, geen account-brede PAT — blast radius blijft één repo.

## Vorm
De server bezit zelf nooit git (upstream weigert dat expliciet). Een los systemd-proces doet het,
draaiend als **dezelfde service-user** als linny-mcp, anders kloppen de bestandsrechten niet.

`git-sync` weigert een branch die niet expliciet is opgegeven; in de unit dus
`branch.<b>.sync true` en `branch.<b>.syncNewFiles true` zetten (agent-schrijfacties zijn
untracked tot ze gecommit worden).

`known_hosts` buiten de working tree houden (bv. `/var/lib/linny-mcp/known_hosts`), anders probeert
git-sync dat bestand mee te synchroniseren.

## Todo
- [ ] ed25519-sleutel genereren; publieke helft als **read/write** deploy key op `torreirow/torrlinny`
- [ ] `secrets/linny-mcp-deploy-key.age` + recipients in `secrets/secrets.nix`; owner = service-user, mode 0400
- [ ] oneshot `linny-mcp-clone.service`: kloont torrlinny naar het corpus als `.git` ontbreekt,
      `before = linny-mcp.service`, `RemainAfterExit = true`
- [ ] `git-sync-linny-mcp.service` + timer (30 s), `WorkingDirectory` = corpus, `GIT_SSH_COMMAND`
      met `IdentitiesOnly=yes` en een eigen `UserKnownHostsFile`
- [ ] `user.name`/`user.email` in de unit zetten, anders faalt de commit
- [ ] verifieer: bestand in het corpus -> staat binnen ~1 min op GitHub
- [ ] verifieer: commit op GitHub -> staat binnen ~1 min in het corpus
- [ ] verifieer: `/var/lib/torrlinny/checkout` is hierdoor niet veranderd
