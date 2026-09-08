---
# nixos-bet5
title: 'torrlinny-build.service: Hugo + Pagefind + atomic swap + keep-last-good'
status: completed
type: feature
priority: normal
created_at: 2026-09-03T05:21:29Z
updated_at: 2026-09-03T06:21:03Z
parent: nixos-anvf
blocked_by:
    - nixos-vegg
---

`torrlinny-build.service` (oneshot): bouwt de site **atomisch** met Hugo + Pagefind.

## Todo
- [ ] `pkgs.hugo` (extended/SCSS-build) + `pkgs.pagefind` beschikbaar maken
- [ ] build: `hugo --minify` → `publishDir` = `lindenIndex/` in een aparte `build.new`-werkarea
- [ ] `pagefind --site <build.new/lindenIndex>` → voegt de `/pagefind`-index toe
- [ ] **atomic swap**: `build.new` → `live` (symlink-swap of rename); nginx serveert altijd `live`
- [ ] **keep-last-good**: faalt hugo/pagefind → live NIET vervangen (vorige goede site blijft staan)
- [ ] `Wants=`+`After=` de sync-stap; draait als `torrlinny`-user

## Notitie
**Runtime-build, GEEN nix-derivation** — geen `nixos-rebuild switch` per notitie-wijziging.



## Summary of Changes
`torrlinny-build.service` (oneshot): overlay+content -> hugo --minify -> pagefind -> atomic symlink-swap naar live; keep-last-good bij fout; prune nieuwste 3. Runtime-build (geen nix-derivation). Bewezen: rev gepubliceerd.
