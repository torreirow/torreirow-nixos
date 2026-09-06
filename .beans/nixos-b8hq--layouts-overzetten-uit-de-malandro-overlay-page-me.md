---
# nixos-b8hq
title: Layouts overzetten uit de malandro-overlay (page-metadata/menu/noteslist)
status: completed
type: feature
priority: normal
created_at: 2026-09-03T14:52:56Z
updated_at: 2026-09-03T16:51:47Z
parent: nixos-al4j
blocked_by:
    - nixos-avpo
---

De layouts uit de malandro-overlay overzetten naar de theme (dit is de kern-look die we al bouwden+testten).

## Todo
- [ ] `layouts/partials/page-metadata.html` — Created (crdate) + Updated (git .Lastmod) op ÉÉN regel
- [ ] `layouts/partials/menu.html` — "Overzichten"-blok bovenaan de zijbalk (links naar notes-by-*)
- [ ] `layouts/partials/menu-filetree.html` — taxonomie-filetree (uit torrlinny)
- [ ] `layouts/_default/noteslist.html` — paginated overzicht (op titel/datum), eigen pager
- [ ] visueel gelijk aan de huidige linny.toorren.net

## Bron
modules/torrlinny/overlay/layouts/* (malandro) — 1-op-1 promoveren naar de theme.
