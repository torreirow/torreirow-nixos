---
# nixos-34vu
title: torrlinny-build.timer + change-detectie (git fetch, HEAD-compare, ~3min)
status: completed
type: feature
priority: normal
created_at: 2026-09-03T05:21:30Z
updated_at: 2026-09-03T06:21:03Z
parent: nixos-anvf
blocked_by:
    - nixos-bet5
---

`torrlinny-build.timer`: periodiek herbouwen, maar **alleen bij een nieuwe commit**.

## Todo
- [ ] timer ~elke 3 min (`OnUnitActiveSec`), `Persistent = true`
- [ ] change-detectie in de build-service: `git fetch`; `HEAD == origin/main`? → skip build, anders bouwen
- [ ] faal → geen live-swap; log/alert

## Notitie
Poll is spotgoedkoop (fetch van ~niets), self-healing, zelfde idioom als rustic/magister-timers. Webhook (instant) komt later als hybride vangnet.



## Summary of Changes
`torrlinny-build.timer`: OnBootSec 2min, OnUnitActiveSec 3min, Persistent. Change-detectie via git fetch + HEAD-compare (build overgeslagen bij geen wijziging). Geverifieerd.
