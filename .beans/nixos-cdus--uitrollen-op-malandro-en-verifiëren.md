---
# nixos-cdus
title: Uitrollen op malandro en verifiëren
status: completed
type: task
priority: normal
created_at: 2026-10-15T13:54:31Z
updated_at: 2026-10-15T15:55:43Z
parent: nixos-s630
blocked_by:
    - nixos-p507
    - nixos-7yie
    - nixos-27oj
---

- [x] nixos-rebuild switch --flake .#malandro
- [x] Footer op agenda.toorren.net toont 'Ingelogd sinds 2026-09-01 …'
- [x] Na de volgende refresh: last_refresh bijgewerkt, token nog geldig
- [x] magister_auth_time_seconds en magister_last_refresh_seconds zichtbaar in Prometheus

## Summary of Changes

Uitgerold op malandro (systeem `26.05.20261008.7c8764b`); magister-sync herstart om 17:52:24.
- Footer: "Ingelogd sinds: 2026-09-01 09:49 (44 dagen)", "Laatste refresh: 2026-10-15 17:52",
  "Token-verloop: onbekend (Magister geeft dit niet prijs)".
- De heartbeat en Prometheus (`localhost:9090`) tonen `magister_auth_time_seconds` = 1788248951 en
  `magister_last_refresh_seconds`.
- De refresh bij het opstarten is geslaagd, het token is geldig en het journal bevat geen tracebacks.
