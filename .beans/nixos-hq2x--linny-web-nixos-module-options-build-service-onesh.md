---
# nixos-hq2x
title: 'linny-web NixOS-module: options + build-service (oneshot) + timer met change-detectie'
status: completed
type: feature
priority: normal
created_at: 2026-09-04T08:32:49Z
updated_at: 2026-09-04T11:37:58Z
parent: nixos-dhh8
---

nix/linny-web.nix, gegeneraliseerd uit modules/torrlinny.nix. options.services.linny-web: enable, gitRepo, gitTokenFile, baseURL, webRoot, stateDir, user, interval, themeModule, configFile (default hugo-web.yaml). build-service: hugo mod get themeModule (go in PATH) -> hugo build (--config configFile --configDir doesnotexist --baseURL) -> atomic swap -> keep-last-good -> prune. timer: OnUnitActiveSec=interval, change-detectie (git HEAD + recept).
