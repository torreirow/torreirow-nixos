---
# nixos-al4j
title: Linny web-view als deelbare Hugo-Module-theme (linny-web-theme)
status: in-progress
type: epic
priority: normal
created_at: 2026-09-03T14:52:09Z
updated_at: 2026-09-03T16:31:33Z
---

Thematische container. De HTML-web-view die we voor torrlinny bouwden (geekdoc + hugo-web.yaml +
overlay) **deelbaar** maken voor álle linny-gebruikers, als herbruikbare **Hugo-Module-theme**.

## Waarom
De web-view zit NIET in `linden-project/linny-notebook-template` (die heeft alleen de indexer voor
linny.vim). Het is nu een eigen toevoeging op torrlinny. Andere linny-gebruikers willen dezelfde
lokale HTML-view kunnen draaien — "zou mooi zijn als we het met een Hugo theme zouden kunnen oplossen".

## Besluiten (uit /opsx:explore)
- **Vorm = Hugo-Module** `github.com/torreirow/linny-web-theme` (nieuw, in torreirow). Importeert
  **geekdoc** transitief (`hugo mod get` haalt alles).
- **Wat we bouwden = de theme-inhoud**: extract van de malandro-overlay (page-metadata Created+Updated
  op 1 regel, menu "Overzichten"-blok, menu-filetree, noteslist) + config-defaults (taxonomieën, menu,
  `frontmatter.date=[crdate,…]`, `enableGitInfo`, `geekdocPageLastmod`).
- **Overzicht-pagina's via Module content-mount** (optie a): `content/notes-by-{title,date}/_index.md`
  leven IN de theme en worden automatisch de site in gemount — nul bestanden in het notebook.
- **fence.py (box-drawing CLI-tabellen) in de runner** (optie a): kan geen theme-ding zijn (theme ziet
  al-geparseerde content). Hoort in `start-web.sh`/RUNME die de template meelevert (preprocess → hugo).
- **Opnemen in `linny-notebook-template`**: hugo-web.yaml (module-import) + start-web.sh, zodat elk
  NIEUW notebook de web-view out-of-the-box heeft.
- **Convergentie met malandro**: torrlinny importeert de theme; `modules/torrlinny.nix` versimpelt
  (overlay eruit) en wordt "gewoon een consumer" die met de theme bouwt (`hugo mod get` in de build).

## Repo's in scope
- NIEUW: `github.com/torreirow/linny-web-theme` (Hugo-Module).
- `linden-project/linny-notebook-template` (module-import + runner opnemen).
- `torreirow/torrlinny` (notebook → theme-import).
- `torreirow/torreirow-nixos` → `modules/torrlinny.nix` versimpelen.

## Ship
Model: één OpenSpec change (`extract-linny-web-theme`) kan de nixos-kant dekken; de theme/template/
notebook-repos zijn losse git-repos. Child-stories spiegelen de fases. `/cas:1shotepic` op deze epic.
