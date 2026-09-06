---
# nixos-p9me
title: verificatie end-to-end + documentatie (CLAUDE.md/docs)
status: completed
type: task
priority: normal
created_at: 2026-09-03T05:21:30Z
updated_at: 2026-09-03T06:28:48Z
parent: nixos-anvf
blocked_by:
    - nixos-34vu
    - nixos-maau
---

End-to-end **verificatie** + **documentatie**.

## Todo
- [ ] push naar `main` → binnen ~3 min herbouwd → nginx toont de update
- [ ] facet-filter + datum-sort + full-text werken visueel in de browser
- [ ] atomic swap / keep-last-good getest: een kapotte build breekt de live-site NIET
- [ ] `CLAUDE.md` (+ evt. `docs/torrlinny.md`) bijwerken met de opzet en beheer-commando's

## Notitie
Verifieer via `curl` (HTTP-codes, updated content) én visueel.



## Summary of Changes
Live op malandro: eerste build publiceert de site (atomic swap naar live-symlink). Geverifieerd: 109 notities, 6 facet-filters + 2 sorts + full-text index; nginx (in torrlinny-groep, werkmap 0750) leest de site; 302 -> Authelia. Change-detectie werkt. docs/torrlinny.md + CLAUDE.md-verwijzing.
