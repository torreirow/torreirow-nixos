---
# nixos-g3id
title: 'Token-status uitlezen: auth_time en laatste refresh'
status: todo
type: task
created_at: 2026-10-15T13:54:30Z
updated_at: 2026-10-15T13:54:30Z
parent: nixos-s630
blocked_by:
    - nixos-cbl4
---

Eén helper in magister_server.py die de sessiestatus geeft voor footer en metrics.

- [ ] auth_time uit de claims van access_token (base64url + json, geen extra dependency)
- [ ] Laatste refresh vastleggen in _refresh_access_token (bv. veld last_refresh in token.json, atomair mee weggeschreven)
- [ ] Ontbrekende of onleesbare waarden geven None, nooit een crash van de sync
- [ ] Geen tokenwaarden in logs
