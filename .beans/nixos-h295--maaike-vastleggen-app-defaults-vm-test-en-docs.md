---
# nixos-h295
title: 'maaike: vastleggen-app-defaults, VM-test en docs'
status: completed
type: task
priority: normal
created_at: 2026-11-04T21:10:32Z
updated_at: 2026-11-05T08:36:17Z
parent: nixos-kzxu
blocked_by:
    - nixos-nuty
    - nixos-s5g5
---

Gouden config vastleggen: script + docs.
- Script `vastleggen-app-defaults` (draait Wouter vanaf lobos via ssh): haalt van mpenzi de config van ZapZap, Signal-instellingen en Spotify-instellingen (niet `prefs` zelf, die gaat via agenix), filtert tokens/cookies/sessiedata eruit, zet het resultaat in `home/profiles/maaike/defaults/`. Laat een diff zien vóór schrijven.
- VM-test voor seeds + herstel-app (zie acceptatiecriteria epic); docs `docs/maaike-app-defaults.md` + indexregel.


## Summary of Changes

- `scripts/vastleggen-app-defaults.sh`: ssh -t + sudo tar naar een bestand op mpenzi, scp, filter op geheime sleutels, diff per bestand, pas schrijven na `j`. Shellcheck schoon; gesimuleerd met nep-ssh (geheim weggefilterd, diff, schrijven).
- VM-test `checks.x86_64-linux.maaike-apps`: 6 subtests groen (seeds, tweede activatie, herstel-app + pkill alleen van maaike, foutmeldingen, signal/spotify, all).
- `docs/maaike-app-defaults.md`, indexregel CLAUDE.md, docs/mpenzi.md, CHANGELOG.
