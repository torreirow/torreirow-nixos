---
# nixos-60h0
title: docs/magister.md bijwerken
status: completed
type: task
priority: normal
created_at: 2026-10-15T13:54:31Z
updated_at: 2026-10-15T14:09:14Z
parent: nixos-s630
blocked_by:
    - nixos-p507
    - nixos-7yie
    - nixos-27oj
---

- [x] Sessieleeftijd via auth_time uitleggen; gemeten: sessie leeft > 44 dagen (login 2026-09-01)
- [x] Refresh-token is opaque: verloop is niet uit te lezen
- [x] Nieuwe footer en metrics beschrijven
- [x] Commando voor sessieleeftijd toevoegen bij 'Handige commando's'
- [x] Rij voor index.html in de bestandentabel controleren

## Summary of Changes

docs/magister.md: nieuwe sectie 'Sessieleeftijd en token-verloop', token.json-velden, testbestand in de tabel, index.html als runtime-bestand, commando's voor sessieleeftijd en unit-tests (live getest).
