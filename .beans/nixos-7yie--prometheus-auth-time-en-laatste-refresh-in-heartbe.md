---
# nixos-7yie
title: 'Prometheus: auth_time en laatste refresh in heartbeat'
status: todo
type: task
created_at: 2026-10-15T13:54:30Z
updated_at: 2026-10-15T13:54:30Z
parent: nixos-s630
blocked_by:
    - nixos-g3id
---

magister_heartbeat.prom uitbreiden:

- [ ] magister_auth_time_seconds (unix-tijd van de passkey-login)
- [ ] magister_last_refresh_seconds (unix-tijd van de laatste geslaagde refresh)
- [ ] HELP/TYPE-regels; metric weglaten als de waarde onbekend is
- [ ] Bewust géén alertregel (levensduurgrens onbekend)
