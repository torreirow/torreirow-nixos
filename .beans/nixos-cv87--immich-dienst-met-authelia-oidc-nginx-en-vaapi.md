---
# nixos-cv87
title: Immich-dienst met Authelia-OIDC, nginx en VAAPI
status: todo
type: task
priority: normal
created_at: 2026-11-02T21:56:32Z
updated_at: 2026-11-02T21:56:47Z
parent: nixos-ypet
blocked_by:
    - nixos-w6ip
---

OpenSpec add-immich-photos, tasks.md groep 2 (2.1-2.6), design D1, D3-D6. OIDC-client immich in Authelia + secrets/immich-oidc.age, modules/immich.nix (ML uit, thumbs/encoded-video via BindPaths lokaal, afhankelijk van de mount), vhost photos.toorren.net zonder forward-auth, rebuild met controle van de gedeelde PostgreSQL na de herstart, eerste admin en OAuth-webtest.
