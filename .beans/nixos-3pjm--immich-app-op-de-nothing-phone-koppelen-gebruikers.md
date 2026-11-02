---
# nixos-3pjm
title: Immich-app op de Nothing Phone koppelen (gebruikerstaak)
status: todo
type: task
priority: normal
created_at: 2026-11-02T23:06:48Z
updated_at: 2026-11-02T23:06:48Z
parent: nixos-ypet
---

Gebruikerstaak uit OpenSpec add-immich-photos taak 3.2 (gearchiveerd). Server-kant is klaar en getest: Authelia accepteert app.immich:///oauth-callback (OAuth-flow tot het loginscherm).

- [ ] Web: https://photos.toorren.net → Inloggen met Authelia (2FA); eigen account wordt aangemaakt
- [ ] Optioneel: eigen account admin maken (Administratie → Gebruikers, als immich-admin@toorren.net)
- [ ] App: server https://photos.toorren.net, OAuth-login; faalt dat, dan fallback mobileRedirectUri (docs/immich.md)
- [ ] Back-up aan in de app (alleen wifi)
- [ ] API-sleutel met het eigen account; invullen in MarkMySteps (Instellingen → Immich) en OwnSteps
