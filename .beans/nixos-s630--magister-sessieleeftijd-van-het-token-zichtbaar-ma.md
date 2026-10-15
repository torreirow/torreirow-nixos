---
# nixos-s630
title: 'Magister: sessieleeftijd van het token zichtbaar maken'
status: completed
type: epic
priority: normal
created_at: 2026-10-15T13:54:11Z
updated_at: 2026-10-15T15:55:43Z
---

De index op agenda.toorren.net toont alleen "Laatste update:". Of de Magister-sessie
gezond is en hoe oud die is, is nergens te zien.

## Wat we weten (gemeten 2026-10-15)

- token.json heeft twee tokens:
  - **access_token**: JWT, 1 uur geldig, wordt bij elke run ververst. De duur is niet interessant.
  - **refresh_token**: een opaque reference-token van 43 tekens, zonder verloopdatum erin. Magister geeft de levensduur niet prijs.
- Het access-token bevat de claim **auth_time** = 2026-09-01 09:49:11, het moment van de
  passkey-login. Die claim reist mee bij elke refresh.
- De sessie leeft dus al 44 dagen zonder re-login. Magisters absolute grens is daarmee
  langer dan 44 dagen; het is dus niet de IdentityServer-standaard van 30 dagen.

## Scope (gekozen: A + B + opruimen)

- **A** Footer van de index: "Ingelogd sinds" (+ leeftijd in dagen), "Laatste refresh" en
  "Token-verloop: onbekend".
- **B** Prometheus: auth_time en laatste refresh in magister_heartbeat.prom. Er komt **geen
  alert**, want de grens is onbekend.
- Opruimen: de verouderde modules/magister/index.html en docs/magister.md bijwerken.

## Buiten scope

- **C** Levensduur leren uit invalid_grant. Pas zinvol na een sessie die echt is doodgegaan.
- Een verloopdatum voorspellen.

## Ontwerpnoot

auth_time uit het JWT lezen met base64 en json, zonder de handtekening te controleren. Dat is
voldoende voor weergave, want de waarde stuurt geen beslissingen aan.

## Summary of Changes

Alle stories zijn af en live op malandro (commits ce5882e en 87f0344).
- Footer met sessieleeftijd en laatste refresh, plus het eerlijke "Token-verloop: onbekend".
- Prometheus-metrics `magister_auth_time_seconds` en `magister_last_refresh_seconds`, zonder alert.
- `last_refresh` in token.json, met de mtime als fallback.
- De verouderde `modules/magister/index.html` is weg en `docs/magister.md` is bijgewerkt. Er zijn 15 unit-tests bij.
- Bijvangst: de index-pagina declareert UTF-8 (`→` in plaats van `â†’`).
