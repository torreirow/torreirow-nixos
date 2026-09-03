---
# nixos-vegg
title: torrlinny checkout/sync (main + submodules) naar /var/lib/torrlinny
status: completed
type: feature
priority: normal
created_at: 2026-09-03T05:21:29Z
updated_at: 2026-09-03T06:21:03Z
parent: nixos-anvf
blocked_by:
    - nixos-iq76
---

Clone/pull van `torrlinny` (branch `main`) **inclusief submodules** naar een werkmap op malandro.

## Todo
- [ ] init: `git clone --recurse-submodules` via de deploy key → `/var/lib/torrlinny` (idempotent: alleen clonen als de map leeg is)
- [ ] update: `git fetch` + `git reset --hard origin/main` + `git submodule update --init --recursive`
- [ ] dedicated service-user (`torrlinny`) + `systemd.tmpfiles` voor de werkmap/rechten

## Notitie
Submodules = themes/PaperMod + themes/hugo-geekdoc (publiek). Alleen de main-repo is privé.



## Summary of Changes
Sync in `torrlinny-build`: clone (--depth 1 --branch main) via de deploy key naar /var/lib/torrlinny/checkout, daarna fetch + reset --hard origin/main. Service-user torrlinny + tmpfiles.
