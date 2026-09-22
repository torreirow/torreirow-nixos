---
# nixos-js5l
title: Automatisch starten/stoppen bij call-detectie
status: draft
type: task
priority: deferred
created_at: 2026-09-22T09:01:03Z
updated_at: 2026-09-22T09:01:03Z
parent: nixos-rtcc
---

Nog geen besluit genomen. Hier vastgelegd zodat het denkwerk niet verdwijnt.

PipeWire verraadt wanneer je in gesprek bent: een `Stream/Input/Audio`-node betekent dat een app NU de microfoon afneemt. De client bestaat al zodra de app draait, de stream-node pas tijdens een gesprek.

Matchen op `application.process.binary`, NIET op `application.name`: Electron-apps heten daar allemaal "Chromium input". Gemeten op lobos geeft `application.process.binary` netjes `slack`, `electron` (Signal/ringrtc), `QtWebEngineProcess`, `firefox`.

## Taken
[ ] besluit: handmatig houden, een `meetrec watch`-lus, of een systemd user service
[ ] allowlist op binary (`slack`, `teams-for-linux`, `jitsi-meet-electron`) — een Signal-belletje is ook gewoon een `Stream/Input/Audio`
[ ] `pw-mon` als trigger

## Bezwaar
Een service die altijd aan staat neemt elk gesprek op zonder dat je er iets voor doet. Technisch het mooist, menselijk het engst. Daarom deferred tot de rest draait.
