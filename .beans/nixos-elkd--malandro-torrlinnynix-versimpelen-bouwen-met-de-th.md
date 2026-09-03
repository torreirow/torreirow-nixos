---
# nixos-elkd
title: 'malandro torrlinny.nix versimpelen: bouwen met de theme (hugo mod)'
status: completed
type: feature
priority: normal
created_at: 2026-09-03T14:52:56Z
updated_at: 2026-09-03T17:15:02Z
parent: nixos-al4j
blocked_by:
    - nixos-vd2b
---

malandro `modules/torrlinny.nix` versimpelen: overlay eruit, bouw torrlinny MÉT de theme (module).

## Todo
- [ ] overlay-copy + web-extra.yaml uit de build-service halen (leeft nu in de theme)
- [ ] `hugo mod get` in de build-stap (Go beschikbaar in de service-PATH) vóór `hugo`
- [ ] fence-preprocessing behouden in de build (of via de gedeelde runner)
- [ ] switch + verifiëren dat linny.toorren.net identiek blijft, keep-last-good intact

## Notitie
Hangt af van S7 (torrlinny moet de theme importeren). Netto: minder custom op malandro.



DONE: modules/torrlinny.nix versimpeld — overlay-copy + web-extra.yaml eruit; 'hugo mod get' toegevoegd (pkgs.go in service-PATH, GOPROXY=direct/GOSUMDB=off, module-cache in werkmap); fence uit de checkout (in-place, .git intact voor enableGitInfo); RECIPE=hugo/go-versie. Switch schoon (exit 0). Live-build op malandro geverifieerd: 156 pages, taxonomie-zijbalk 10/15/7/2, Created-datum, Overzichten, search-index, geekdoc-css — identiek. keep-last-good intact. Eenmalig verouderde checkout (read-only overlay-restanten) gewist.
