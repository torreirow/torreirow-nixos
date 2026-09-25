---
# nixos-tdv7
title: Whisper-transcriptie per spoor
status: completed
type: task
priority: normal
created_at: 2026-09-22T09:00:47Z
updated_at: 2026-09-22T10:05:30Z
parent: nixos-rtcc
---

## Taken
[ ] `meetrec transcribe <map>` -> whisper per spoor, twee losse transcripten
[ ] samenvoegen tot een tijdgeordend transcript met sprekerlabels (ik / anderen)
[ ] `nice`/`ionice`, en expliciet NA de meeting
[ ] modelkeuze meten, niet aannemen: `openai-whisper` staat al op lobos, maar `whisper-cpp` en `whisper-ctranslate2` zitten in nixpkgs en zijn op CPU een andere orde

## Besluit
Sprekerscheiding komt uit de twee sporen, niet uit een diarisatiemodel. Dat is de hele reden dat we niet live mixen.


## Summary of Changes

`meetrec transcribe [map]` draait whisper per spoor naar SRT (met `nice`/`ionice`) en voegt die
samen met `merge-transcripts.py` tot `transcript.txt`: tijdgeordend, met `[ik]`/`[anderen]` per
regel. Sprekerscheiding komt dus uit de opnamestructuur, niet uit een diarisatiemodel.

End-to-end geverifieerd op de proefopname: whisper herkende de testtoon als "MUZIEK" en leverde
een correct samengevoegd transcript. **Gemeten: 78 s wall voor 2 × 35 s audio met het
`turbo`-model op CPU (~1,1× realtime per spoor).** Dat onderstreept het besluit om transcriptie
altijd ná het gesprek te draaien.

Daarnaast `merge_transcripts_test.py` met 16 assertions (volgorde, labels, meerregelige blokken,
leeg spoor, ontbrekend spoor) — draait zonder whisper, audio of netwerk.
