---
# nixos-oosu
title: torrlinny.nix herschrijven als thin wrapper (agenix key + services.linny-web + Authelia-vhost)
status: completed
type: task
priority: normal
created_at: 2026-09-04T13:43:00Z
updated_at: 2026-09-04T13:51:46Z
parent: nixos-9596
---

modules/torrlinny.nix: houd options.services.torrlinny.enable/domain/acmeHost; config zet age.secrets.torrlinny-deploy-key + services.linny-web (gitSshKeyFile, user torrlinny, stateDir /var/lib/torrlinny, webRoot .../live, baseURL) + SupplementaryGroups keys op linny-web-build + eigen Authelia-vhost (autheliaVerifyLocation/autheliaAuthConfig). Verwijder oude user/tmpfiles/service/timer/buildScript.
