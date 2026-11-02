---
# nixos-kvys
title: Koppeling reisapps (API-sleutel) en Immich-app op de telefoon
status: completed
type: task
priority: normal
created_at: 2026-11-02T21:56:32Z
updated_at: 2026-11-02T23:07:11Z
parent: nixos-ypet
blocked_by:
    - nixos-cv87
---

OpenSpec add-immich-photos, tasks.md groep 3 (3.1-3.2). API-sleutel voor MarkMySteps en OwnSteps, bereikbaarheid vanuit beide containers. 3.2 is een gebruikerstaak (telefoon): de agent levert de instructie en wacht op bevestiging; fallback mobileRedirectUri uit design D5 als de custom scheme faalt.


## Summary of Changes
- Immich bereikbaar vanuit markmysteps-api en ownsteps (ping = pong op https://photos.toorren.net).
- API-sleutel hoort bij de gebruiker: aanmaken met het eigen OIDC-account; instructie in docs/immich.md.
- De telefoon- en sleutelstappen van de gebruiker staan in bean nixos-3pjm.
