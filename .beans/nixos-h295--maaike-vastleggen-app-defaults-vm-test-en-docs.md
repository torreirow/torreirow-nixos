---
# nixos-h295
title: 'maaike: vastleggen-app-defaults, VM-test en docs'
status: todo
type: task
created_at: 2026-11-04T21:10:32Z
updated_at: 2026-11-04T21:10:32Z
parent: nixos-kzxu
blocked_by:
    - nixos-nuty
    - nixos-s5g5
---

Gouden config vastleggen: script + docs.
- Script `vastleggen-app-defaults` (draait Wouter vanaf lobos via ssh): haalt van mpenzi de config van ZapZap, Signal-instellingen en Spotify-instellingen (niet `prefs` zelf, die gaat via agenix), filtert tokens/cookies/sessiedata eruit, zet het resultaat in `home/profiles/maaike/defaults/`. Laat een diff zien vóór schrijven.
- VM-test voor seeds + herstel-app (zie acceptatiecriteria epic); docs `docs/maaike-app-defaults.md` + indexregel.
