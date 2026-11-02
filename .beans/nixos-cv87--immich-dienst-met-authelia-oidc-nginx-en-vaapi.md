---
# nixos-cv87
title: Immich-dienst met Authelia-OIDC, nginx en VAAPI
status: completed
type: task
priority: normal
created_at: 2026-11-02T21:56:32Z
updated_at: 2026-11-02T23:07:10Z
parent: nixos-ypet
blocked_by:
    - nixos-w6ip
---

OpenSpec add-immich-photos, tasks.md groep 2 (2.1-2.6), design D1, D3-D6. OIDC-client immich in Authelia + secrets/immich-oidc.age, modules/immich.nix (ML uit, thumbs/encoded-video via BindPaths lokaal, afhankelijk van de mount), vhost photos.toorren.net zonder forward-auth, rebuild met controle van de gedeelde PostgreSQL na de herstart, eerste admin en OAuth-webtest.


## Summary of Changes
- Immich 3.3.5 uit unstable (pakket + module, flake.nix): 26.05 heeft alleen 2.7.5 (insecure).
- modules/immich.nix: 127.0.0.1:2283, ML uit, video op de CPU (VAAPI faalde, vervolg nixos-umuq), thumbs/encoded-video via BindPaths naar /data/external/immich, BindsTo + mountpoint-check op de JuiceFS-mount (getest).
- Authelia-client immich (two_factor, client_secret_post, redirects web + app.immich:///oauth-callback); OAuth-flow tot het Authelia-loginscherm getest.
- nginx photos.toorren.net zonder forward-auth; ping = pong.
- Admin immich-admin@toorren.net (wachtwoord in secrets/immich-admin-password.age); upload via API getest, testassets weer verwijderd.
