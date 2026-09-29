---
# nixos-vlhs
title: Documentatie bijwerken
status: completed
type: task
priority: normal
created_at: 2026-09-29T20:00:28Z
updated_at: 2026-09-29T20:12:35Z
parent: nixos-b25k
---

- [x] `docs/linny-mcp.md`: een sectie over de drie klokken (sessie-cookie,
      access-token, refresh-token), welke waarvan is, en waarom de sessie-cookie
      er bewust buiten blijft. Nu staat er niets over levensduur, terwijl dat de
      meest merkbare eigenschap van de koppeling is
- [x] Vastleggen dat "onthoud mij" bij het inloggen de juiste hefboom is voor de
      browsersessie — per keer en zelfgekozen, in plaats van globaal losser
- [x] `CHANGELOG.md` onder `## NEXT VERSION`


## Summary of Changes

`docs/linny-mcp.md` heeft een sectie "Drie klokken, en welke waarvan is": een
tabel met de sessie-cookie, de access-token en de refresh-token, wat elk
beschermt en waaraan je het merkt. Met de meting van 29 september erbij, en de
uitleg dat het "onthoud mij"-vinkje op het inlogformulier staat en niet op het
toestemmingsscherm — dat leverde vandaag nog verwarring op.

`CHANGELOG.md` onder `## NEXT VERSION`, als `### Changed`.
