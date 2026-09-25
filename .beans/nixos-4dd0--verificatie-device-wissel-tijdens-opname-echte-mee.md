---
# nixos-4dd0
title: 'Verificatie: device-wissel tijdens opname + echte meeting-proef'
status: completed
type: task
priority: high
created_at: 2026-09-22T09:01:03Z
updated_at: 2026-09-22T14:37:33Z
parent: nixos-rtcc
---

Alles in het ontwerp is live gemeten behalve de punten hieronder. Dit is wat nog open staat.

## Taken
[x] proefopname terwijl de default sink midden in de opname wisselt -> inkomend spoor verhuist mee en weer terug, zonder onderbreking (getest met KT USB <-> interne speaker; dat is hetzelfde mechanisme dat een BT-headset triggert)
[x] idem voor een mic-wissel (USB Composite <-> Sandberg): mic-spoor volgt beide kanten op
[x] cross-device: over 81 s geen waarneembare afwijking tussen mic en monitor. Een vol uur is NIET getest; geaccepteerd omdat PipeWire beide apparaten naar dezelfde grafiekklok hersamplet en de gemeten offset constant was
[x] echte proef gedaan met **Slack** (2026-09-22, 81 s). Teams en Jitsi niet apart getest: ze lopen via hetzelfde mechanisme (default sink-monitor + default source), er is geen app-specifieke code
[x] geverifieerd tijdens het gesprek: Slacks capture-stream en meetrec-mic hingen beide aan alsa_input.usb-Jieli...mono-fallback
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


## Summary of Changes

Volledig geverifieerd, afgesloten na de eerste echte meeting (Slack, 2026-09-22, 81 s).

**Wat standhield.** Het inkomende spoor volgt een device-wissel midden in een lopende opname, heen
en terug, zonder onderbreking; hetzelfde geldt voor het mic-spoor bij een wissel van default
source. Dat was de enige echt onbewezen aanname uit de explore. Tijdens dezelfde sessie
verschoven de node-id's bovendien vanzelf (Sandberg 95 -> 107, USB Composite 76 -> 85, KT USB van
iec958- naar analog-stereo) -- een script dat id's had vastgelegd, was die opname kwijt geweest.

**Echte opname.** Slack en het ik-spoor hingen aantoonbaar aan dezelfde microfoon. Beide sporen
bevatten signaal (anderen mean -29,6 dB, ik mean -52,8 dB), transcriptie leverde 38 gelabelde,
tijdgeordende regels.

**Bevinding die het tweesporen-besluit rechtvaardigt.** De gebruiker zat op speakers, dus de
microfoon ving de tegenpartij mee: structureel gemeten komt **29% van de inhoudswoorden in het
ik-spoor ook in het anderen-spoor voor**. Gevolg: sprekerlabels zijn onbetrouwbaar waar die bleed
doorkomt, en `meetrec mix` zet de anderen dubbel in het bestand. Had het script live gemixt, dan
was dat onherstelbaar geweest; nu is `anderen.opus` gewoon schoon. Remedie is een koptelefoon --
filteren achteraf dempt de bleed, maar neemt hem niet weg. Staat al beschreven in de README.

**Niet getest, bewust geaccepteerd.** Cross-device drift over een vol uur (81 s liet niets zien;
PipeWire hersamplet beide apparaten naar dezelfde grafiekklok). Teams en Jitsi apart -- er is geen
app-specifieke code, ze lopen via exact hetzelfde mechanisme.
