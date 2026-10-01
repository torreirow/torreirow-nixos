---
# nixos-aw03
title: 'linny-mcp: flake-input naar fork torreirow/linny-mcp-server'
status: todo
type: feature
tags:
    - linny-mcp
    - fork
created_at: 2026-10-01T22:03:45Z
updated_at: 2026-10-01T22:03:45Z
parent: nixos-m0vn
---

Besluit 2026-10-01: linny-mcp-server wordt geforkt naar `torreirow/linny-mcp-server` (fork-first, later upstreamen). De fork zelf en de code-wijzigingen staan in de home-tracker (`~/.beans`): wtoorren-67t4 (forks opzetten), wtoorren-e1z5 (archive-tool schrijft `archived` i.p.v. `archive`), wtoorren-77mg (archief standaard verbergen + `include_archived`), epic wtoorren-kjjk.

Deze bean dekt alleen de kant van torreirow-nixos.

- [ ] `flake.nix`: `linny-mcp.url = "github:torreirow/linny-mcp-server"` (overlay en `nixosModules.linny-mcp` blijven gelijk)
- [ ] `modules/linny-mcp.nix`: commentaar 'Dunne wrapper rond de upstream ...' bijwerken naar de fork
- [ ] `nix flake lock --update-input linny-mcp`, malandro bouwen en switchen
- [ ] Controleren: `session_info` meldt de fork-versie, `verify_index` in sync
- [ ] Bij elke merge in fork-`main` (eerst wtoorren-e1z5): input opnieuw bumpen
