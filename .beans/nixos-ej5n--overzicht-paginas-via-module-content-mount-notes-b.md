---
# nixos-ej5n
title: Overzicht-pagina's via Module content-mount (notes-by-title/date)
status: completed
type: feature
priority: normal
created_at: 2026-09-03T14:52:56Z
updated_at: 2026-09-03T16:51:47Z
parent: nixos-al4j
blocked_by:
    - nixos-avpo
---

De twee overzicht-pagina's via **Module content-mount** in de theme leveren (optie a) — nul bestanden in het notebook.

## Todo
- [ ] `content/notes-by-title/_index.md` (layout: noteslist, sortby: title) in de theme
- [ ] `content/notes-by-date/_index.md` (layout: noteslist, sortby: date) in de theme
- [ ] verifiëren dat Hugo de module-content de site in mount (pagina's verschijnen zonder notebook-bestanden)
- [ ] noteslist filtert op echte notes (`where site.RegularPages "Params.crdate" "!=" nil`)



DONE: content/notes-by-{title,date}/_index.md leven in de theme; via echte 'hugo mod get' verschijnt /notes-by-title/ in een consumer zonder notebook-bestanden. noteslist filtert op Params.crdate!=nil.
