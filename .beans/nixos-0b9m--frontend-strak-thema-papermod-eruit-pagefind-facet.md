---
# nixos-0b9m
title: 'frontend: strak thema (PaperMod eruit) + Pagefind facet/zoek/datum-sort'
status: completed
type: feature
priority: normal
created_at: 2026-09-03T05:21:29Z
updated_at: 2026-09-03T06:21:03Z
parent: nixos-anvf
blocked_by:
    - nixos-bet5
---

Frontend: **PaperMod eruit**, strak thema + **Pagefind faceted zoek/datum-sort** integreren. Dit levert de drie eisen.

## Todo
- [ ] PaperMod verwijderen/uitschakelen; strak thema kiezen (bv. Hextra) of minimale custom-layout
- [ ] per notitie `data-pagefind-filter` emitten voor **customer/project/type/tag/owner/subject/doctype**
- [ ] `data-pagefind-sort` voor **datum/tijd** (frontmatter date)
- [ ] Pagefind UI (facet-sidebar + full-text zoekbalk) in de layout integreren
- [ ] markdown-rendering + typografie nalopen (leesbaar én mooi)

## Notitie
Facet-filter + datum-sort + full-text = precies de eisen. Client-side, statisch.



## Summary of Changes
Zelfstandige Hugo-overlay (modules/torrlinny/overlay: config+layouts+css), PaperMod niet gebruikt. data-pagefind-filter per taxonomie (minify-veilig als tekst-inhoud) + data-pagefind-sort op crdate. Pagefind-UI + strak light/dark thema. Geverifieerd: 6 facets, 2 sorts, 109 notities.
