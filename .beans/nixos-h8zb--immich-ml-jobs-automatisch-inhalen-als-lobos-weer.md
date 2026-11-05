---
# nixos-h8zb
title: Immich ML-jobs automatisch inhalen als lobos weer online komt
status: in-progress
type: task
priority: deferred
created_at: 2026-11-05T10:37:23Z
updated_at: 2026-11-05T11:44:24Z
parent: nixos-esgu
---

Na nixos-esgu draait Immich-ML op lobos. Uploads terwijl lobos uit is krijgen geen embeddings/gezichten; nu handmatig Administratie → Taken → Ontbrekende.

Idee: timer op malandro die bij healthy ML (curl 10.77.0.2:3003/ping) via de Immich-API smartSearch en faceDetection met force=false start. Vereist een admin-API-sleutel als agenix-secret. Eerst kijken of het handmatig vaak genoeg nodig is.
