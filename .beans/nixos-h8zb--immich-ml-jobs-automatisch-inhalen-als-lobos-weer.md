---
# nixos-h8zb
title: Immich ML-jobs automatisch inhalen als lobos weer online komt
status: completed
type: task
priority: deferred
created_at: 2026-11-05T10:37:23Z
updated_at: 2026-11-05T12:02:16Z
parent: nixos-esgu
---

Na nixos-esgu draait Immich-ML op lobos. Uploads terwijl lobos uit is krijgen geen embeddings/gezichten; nu handmatig Administratie → Taken → Ontbrekende.

Idee: timer op malandro die bij healthy ML (curl 10.77.0.2:3003/ping) via de Immich-API smartSearch en faceDetection met force=false start. Vereist een admin-API-sleutel als agenix-secret. Eerst kijken of het handmatig vaak genoeg nodig is.

## Summary of Changes

- `modules/immich-ml-catchup/` (malandro): oneshot + timer (10 min). Pingt ML op lobos; bij down→up, eerste run of na 6 uur start hij `PUT /api/jobs/{smartSearch,faceDetection}` met `force=false`. Toestand in `/var/lib/immich-ml-catchup/state`.
- API-sleutel `ml-catchup` (admin, alleen `job.create`) in `secrets/immich-ml-catchup-key.age`, via LoadCredential + DynamicUser; sleutel niet in de proceslijst. Zonder secret staat de timer uit (warning).
- Test: flake-check `checks.x86_64-linux.immich-ml-catchup` (script tegen nep-server, 6 gevallen).
- Live getest 2026-11-05: eerste run startte beide jobs (HTTP 200); ML op lobos gestopt → "onbereikbaar, niets gestart"; weer gestart → beide jobs gestart.
- Docs: `docs/immich.md` (inhaal-timer, sleutel maken). OpenSpec `immich-ml-catchup` gearchiveerd.
