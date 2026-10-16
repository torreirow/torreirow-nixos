---
# nixos-g3id
title: 'Token-status uitlezen: auth_time en laatste refresh'
status: completed
type: task
priority: normal
created_at: 2026-10-15T13:54:30Z
updated_at: 2026-10-15T14:09:14Z
parent: nixos-s630
blocked_by:
    - nixos-cbl4
---

Eén helper in magister_server.py die de sessiestatus geeft voor footer en metrics.

- [x] auth_time uit de claims van access_token (base64url + json, geen extra dependency)
- [x] Laatste refresh vastleggen in _refresh_access_token (bv. veld last_refresh in token.json, atomair mee weggeschreven)
- [x] Ontbrekende of onleesbare waarden geven None, nooit een crash van de sync
- [x] Geen tokenwaarden in logs

## Summary of Changes

`session_status()` (pure functie) en `MagisterServerClient.session_status()` in magister_server.py. `auth_time` komt uit het JWT-payload (stdlib, geen signature-check). `_refresh_access_token` schrijft `last_refresh` atomair mee, met mtime-fallback voor oude bestanden. Onleesbaar levert None op. Getest met unit-tests en tegen het echte token.json (auth_time 2026-09-01 09:49:11).
