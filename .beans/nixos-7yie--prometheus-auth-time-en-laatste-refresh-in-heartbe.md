---
# nixos-7yie
title: 'Prometheus: auth_time en laatste refresh in heartbeat'
status: completed
type: task
priority: normal
created_at: 2026-10-15T13:54:30Z
updated_at: 2026-10-15T14:09:14Z
parent: nixos-s630
blocked_by:
    - nixos-g3id
---

magister_heartbeat.prom uitbreiden:

- [x] magister_auth_time_seconds (unix-tijd van de passkey-login)
- [x] magister_last_refresh_seconds (unix-tijd van de laatste geslaagde refresh)
- [x] HELP/TYPE-regels; metric weglaten als de waarde onbekend is
- [x] Bewust géén alertregel (levensduurgrens onbekend)

## Summary of Changes

write_heartbeat(session) exporteert magister_auth_time_seconds en magister_last_refresh_seconds met HELP/TYPE. Onbekende waarden worden weggelaten. De bestaande heartbeat-metric is ongewijzigd en er is geen alert toegevoegd. Unit-tests: HeartbeatTest.
