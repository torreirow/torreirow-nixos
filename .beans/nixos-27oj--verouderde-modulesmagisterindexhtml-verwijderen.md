---
# nixos-27oj
title: Verouderde modules/magister/index.html verwijderen
status: completed
type: task
priority: normal
created_at: 2026-10-15T13:54:31Z
updated_at: 2026-10-15T14:09:14Z
parent: nixos-s630
---

De index.html in de repo is een stale kopie ("Elke 10 minuten", laatste update 2026-08-31). De echte wordt gegenereerd in /var/lib/magister.

- [x] Controleren dat niets (nix-module, scripts) naar dit bestand verwijst
- [x] Bestand verwijderen

## Summary of Changes

Geverifieerd dat geen nix-module of script naar modules/magister/index.html verwijst (alleen het runtime-pad /var/lib/magister/index.html). Het bestand is verwijderd.
