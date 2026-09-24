---
# nixos-w6hy
title: Mapstructuur per gesprek + Opus-encoding na afloop
status: completed
type: task
priority: normal
created_at: 2026-09-22T09:00:36Z
updated_at: 2026-09-22T10:05:30Z
parent: nixos-rtcc
---

## Taken
[ ] map per opname, bv. `~/Meetings/2026-09-22-1430/`
[ ] rauwe WAV tijdens de opname (~350 MB/uur per spoor); encoderen pas bij `stop`
[ ] Opus 32k mono per spoor (~15 MB/uur) — meteen het formaat dat whisper wil
[ ] WAV pas opruimen na succesvolle encoding, niet eerder
[ ] encoding met `nice`/`ionice`

## Besluit
Niet tijdens de call encoden: de 7840U throttelt onder aanhoudende last.


## Summary of Changes

Map per gesprek (`~/Meetings/YYYY-MM-DD-HHMM[-naam]`), rauwe WAV tijdens de opname, Opus 32k mono
bij `stop` met `nice`/`ionice`. WAV wordt pas verwijderd nadat de encoding geslaagd is; mislukt
ze, dan blijft het origineel staan en meldt het commando dat.

Gemeten in de proefopname: 35 s opname → anderen.opus 150 KB (34,7 kbit/s), ik.opus 120 KB, beide
mono. Rauw was dat ~2,2 MB resp. ~1,1 MB.
