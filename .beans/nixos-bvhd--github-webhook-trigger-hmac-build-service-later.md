---
# nixos-bvhd
title: GitHub webhook-trigger (HMAC) -> build-service [LATER]
status: draft
type: feature
priority: low
created_at: 2026-09-03T05:21:30Z
updated_at: 2026-09-03T05:21:30Z
parent: nixos-anvf
blocked_by:
    - nixos-bet5
---

**LATER / draft** — GitHub push-webhook triggert dezelfde build-service (instant i.p.v. wachten op de timer). BUITEN scope van de eerste `/cas:1shotepic`-run.

## Todo
- [ ] webhook-ontvanger (adnanh/`webhook` of klein eigen service) achter nginx, endpoint bv. `/hooks/rebuild`
- [ ] **HMAC-secret** (agenix) verifiëren; alleen reageren op push naar `main`
- [ ] triggert `systemctl start torrlinny-build.service`
- [ ] timer blijft staan als **vangnet** (hybride, `Persistent`)

## Notitie
Bewust `draft`: pas oppakken nadat de timer-variant staat en bevalt.
