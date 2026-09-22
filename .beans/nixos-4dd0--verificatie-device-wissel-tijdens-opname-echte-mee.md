---
# nixos-4dd0
title: 'Verificatie: device-wissel tijdens opname + echte meeting-proef'
status: in-progress
type: task
priority: high
created_at: 2026-09-22T09:01:03Z
updated_at: 2026-09-22T10:06:46Z
parent: nixos-rtcc
---

Alles in het ontwerp is live gemeten behalve de punten hieronder. Dit is wat nog open staat.

## Taken
[x] proefopname terwijl de default sink midden in de opname wisselt -> inkomend spoor verhuist mee en weer terug, zonder onderbreking (getest met KT USB <-> interne speaker; dat is hetzelfde mechanisme dat een BT-headset triggert)
[x] idem voor een mic-wissel (USB Composite <-> Sandberg): mic-spoor volgt beide kanten op
[ ] mic + monitor lopen over twee verschillende USB-klokken; controleren dat de sporen ook cross-device niet uit elkaar lopen over een gesprek van een uur
[ ] echte proef met Teams, Slack en Jitsi
[ ] controleren dat het eigen spoor de mic pakt die de meeting-app ook gebruikt
[x] `meetrec stop` na een crash van een van beide processen: SIGKILL op de mic-opnemer -> `status` meldt OMGEVALLEN, `stop` comprimeert beide sporen alsnog (ffmpeg leest een niet-afgesloten WAV tot EOF)

## Waarom high
Valt de device-wissel verkeerd uit, dan verandert dat het ontwerp (dan moet het script de default bewaken i.p.v. erop vertrouwen).


## Stand 2026-09-22

Geverifieerd (automatisch, deze sessie):
- **Default sink wisselen tijdens een lopende opname**: het inkomende spoor verhuisde mee naar
  de interne speaker en weer terug naar KT USB, zonder onderbreking. Dit was de enige echt
  onbewezen aanname uit de explore. Hij houdt stand.
- **Default source wisselen**: idem voor het mic-spoor (USB Composite <-> Sandberg).
- **Crash van een opnemer**: SIGKILL op de mic-opnemer -> `status` meldt OMGEVALLEN,
  `stop` comprimeert beide sporen alsnog.
- Dubbele `start` wordt geweigerd; `stop` zonder lopende opname faalt netjes met exit 1;
  `status` zonder opname geeft exit 0.
- Volledige keten start -> stop -> mix -> transcribe op een echte proefopname.

**Bewijs achteraf dat node-id-vrij de juiste keuze was:** tussen twee metingen in dezelfde
sessie verschoven de node-id's vanzelf -- de Sandberg ging van 95 naar 107, de USB Composite
van 76 naar 85, en de KT USB-sink wisselde van `iec958-stereo` naar `analog-stereo`. Een script
dat bij het starten een node-id had vastgelegd, had die opname verloren.

Nog open (handwerk, kan niet vanuit de CLI):
- echte proef met Teams, Slack en Jitsi, met daadwerkelijke deelnemers;
- controleren dat het eigen spoor de mic pakt die de meeting-app zelf ook gebruikt;
- cross-device drift over een volledig uur (mic en monitor lopen over twee USB-klokken; over
  35 s was er niets van te zien, maar een uur is niet getest).
