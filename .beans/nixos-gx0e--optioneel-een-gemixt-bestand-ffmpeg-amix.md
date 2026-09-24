---
# nixos-gx0e
title: Optioneel een gemixt bestand (ffmpeg amix)
status: completed
type: task
priority: normal
created_at: 2026-09-22T09:00:47Z
updated_at: 2026-09-22T10:05:30Z
parent: nixos-rtcc
---

`meetrec mix <map>` (of een `--mix`-vlag) die van de twee sporen een enkel bestand maakt, voor wanneer je "het gehele audio" als een bestand wilt doorgeven.

## Taken
[ ] `ffmpeg -i anderen.opus -i ik.opus -filter_complex amix=inputs=2:normalize=0 ...`
[ ] de losse sporen blijven staan; de mix is een extra bestand, geen vervanging
[ ] niveaubalans instelbaar (het eigen spoor is doorgaans veel harder dan de inkomende kant)

## Besluit
Mixen mag, omdat de sporen niet uit elkaar lopen: gemeten constante offset ~10,7 ms zonder drift. Zie epic.

## Let op
Zat je op speakers, dan staan de anderen dubbel in de mix (je mic hoorde ze mee). Dan de mix overslaan; de losse sporen blijven de bron van waarheid.


## Summary of Changes

`meetrec mix [map]` voegt de sporen samen met `amix=inputs=2:duration=longest:normalize=0:weights=...`
en schrijft `meeting.opus`; de losse sporen blijven staan. `normalize=0` is bewust: met
normalize=1 halveert ffmpeg beide kanten en wordt alles zacht. De balans regel je met de optie
`mixWeights` (volgorde: `anderen ik`).

Geverifieerd: mix van de proefopname is 34,8 s (duration=longest) met max_volume -28,6 dB, dus
het signaal uit beide sporen zit erin, en beide bronbestanden staan er nog.
