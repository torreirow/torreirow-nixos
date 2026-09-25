---
# nixos-rtcc
title: 'Meeting-opname: inkomende audio + eigen microfoon (lobos)'
status: completed
type: epic
priority: normal
created_at: 2026-09-22T09:00:23Z
updated_at: 2026-09-22T14:37:52Z
---

Thematic container. Een CLI-opnamescript voor lobos dat van een meeting (Teams, Slack, Jitsi) zowel de inkomende audio als de eigen microfoon vastlegt.

## Doel
Na afloop van een gesprek een bruikbaar geluidsbestand hebben, en daaruit een transcript met sprekerscheiding. "Het gehele audio": inkomend EN uitgaand, niet een van beide.

## Architectuur-besluiten (uit /opsx:explore 2026-09-22 — live gemeten op lobos)
- **Twee sporen, geen live mix.** `anderen.wav` (inkomend) en `ik.wav` (mic) als losse bestanden; achteraf desgewenst mixen. Winst: niveaus achteraf corrigeerbaar, echo-op-speakers te redden, en whisper leest de sporen los -> sprekerscheiding zonder diarisatiemodel.
- **Geen apparaatnamen of node-id's in het script.** Inkomend via `pw-record -P '{ stream.capture.sink=true }'`: WirePlumber koppelt die stream zelf aan de monitor van de *huidige* default sink (live geverifieerd, links naar `alsa_output.usb-KTMicro...iec958-stereo:monitor_FL/FR`). De mic via kale `pw-record` -> default source. Beide verhuizen mee bij een device-wissel.
- **Klokdrift is geen probleem.** Twee onafhankelijke `pw-record`-processen gemeten met een toon op twee meetpunten: offset 10.666 ms resp. 10.667 ms — identiek tot op de microseconde, dus constante offset zonder oplopende drift. PipeWire hersampelt elk apparaat naar een gemeenschappelijke grafiekklok. Kanttekening: beide opnemers hingen in die test aan dezelfde bron; mic + monitor over twee USB-klokken is niet geforceerd getest (zie verificatie-bean).
- **Speakervolume zit niet in de opname.** `monitor.channel-volumes` is niet gezet -> PipeWire-default `false`; monitor- en playbackvolume zijn losse regelaars.
- **Geen nieuwe pakketten nodig.** PipeWire 1.6.6 (`pw-record`/`pw-link`/`pw-cli`/`pw-loopback`), `ffmpeg-full` en `openai-whisper` staan al in `hosts/lobos/programs.nix`. `pactl` en `sox` ontbreken op lobos — daar niet op rekenen.

## Verworpen alternatieven
- **Alleen de default output opnemen.** Simpelst, maar Teams/Slack/Jitsi spelen je eigen mic niet terug naar de sink, dus je eigen stem ontbreekt volledig. Afgewezen: beide kanten zijn expliciet gewenst.
- **Live mixen in PipeWire** (null-sink `MeetRec` + twee `pw-loopback`'s + `pw-record --target`). Levert een sample-synchroon bestand, maar vier objecten i.p.v. twee en een echte terugkoppellus zodra `MeetRec` per ongeluk de default sink wordt. Geen winst boven achteraf mixen.
- **Per-app aftappen** (eigen null-sink, of `pw-link` op de app-poorten). Zou muziek en notificaties buiten de opname houden, maar Electron-apps maken bij elke call een nieuwe node -> links telkens opnieuw leggen. Prijs te hoog; systeemgeluid in het inkomende spoor accepteren we.
- **`acp63` / `hw:2,0` (ingebouwde dekselmic).** Capture-only DMIC-array van de P16s Gen 2. Kaart 2 heeft geen PipeWire-node: WirePlumber logde bij boot exact een mislukte kaart (`SPA handle 'api.alsa.acp.device' could not be loaded`), en alle overige nodes mappen op kaart 0/1/3/5/6. Onbereikbaar voor `pw-record`; rauw `arecord -D hw:2,0` is exclusief (bleek bezet door audacity, pid 1552050). Levert bovendien alleen een slechte far-field versie van je eigen stem, nooit de inkomende kant. **Acp63 in PipeWire krijgen valt bewust buiten deze epic.**
- **OBS.** Alleen zinnig zodra er ook beeld mee moet.

## Randvoorwaarden
- Encoden en transcriberen NA afloop, niet tijdens. De 7840U throttelt onder aanhoudende last (zie epic/change `throttle-nix-builds`); whisper draait op normale prioriteit en concurreert dus met de call. `nice`/`ionice` gebruiken.
- Default source is nu `USB Composite Device Mono` (kaart 3), maar er zijn ook de Sandberg (kaart 6, door `hosts/lobos/configuration.nix:220` op 77% vastgezet) en een Bluetooth-headset (`bluez_output.98_29_EA_63_46_4C`). "Volg de default" is daarom niet alleen het makkelijkst maar ook het enige dat klopt.
- Systeemgeluid (mpv/Strawberry, Signal-belgeluid, notificaties) loopt mee in het inkomende spoor. Bewust geaccepteerd.
- Opname van een gesprek waaraan je zelf deelneemt is in NL toegestaan; verspreiden is een aparte vraag.

## Ship
Model A: een OpenSpec change `add-meeting-record` dekt de hele epic. Child-beans spiegelen de fases voor tracking.


## Stand 2026-09-22 -- implementatie af, één verificatiepunt open

OpenSpec change `add-meeting-record` geïmplementeerd, geverifieerd en gearchiveerd als
`2026-09-22-add-meeting-record`; hoofdspec staat in `openspec/specs/meeting-record/`.

Opgeleverd: `home/module/meeting-record/` met `meetrec start|stop|status|list|mix|transcribe`,
geïmporteerd in `flake.nix` en aangezet in `home/linux-desktop.nix`.

Vier van de vijf child-beans zijn afgerond. `nixos-4dd0` blijft open voor wat niet vanuit de CLI
kan: een echte meeting met deelnemers, en cross-device drift over een vol uur. `nixos-js5l`
(automatische call-detectie) blijft bewust draft/deferred.

**De belangrijkste onbewezen aanname uit de explore is gesneuveld in ons voordeel:** het
inkomende spoor volgt een device-wissel midden in een lopende opname, heen en terug, zonder
onderbreking. Tijdens dezelfde sessie bleek bovendien dat node-id's vanzelf verschuiven
(Sandberg 95 -> 107, USB Composite 76 -> 85, KT USB van iec958- naar analog-stereo) -- een script
dat id's had vastgelegd, had die opname verloren.

Nog te doen door de gebruiker: `home-manager switch` draaien om `meetrec` op het PATH te krijgen.


## Summary of Changes

Afgerond 2026-09-22. `home/module/meeting-record/` levert `meetrec` met
start/stop/status/list/mix/transcribe; geïmporteerd in `flake.nix`, aangezet in
`home/linux-desktop.nix`, live op lobos na `home-manager switch`.

OpenSpec change `add-meeting-record` geïmplementeerd en gearchiveerd als
`2026-09-22-add-meeting-record`; hoofdspec (8 requirements) in `openspec/specs/meeting-record/`.
Commit `d32173a`.

**Alle vier de architectuurbesluiten hielden stand in de praktijk:**
- twee sporen zonder live mix -- rechtgezet door de allereerste echte opname, waarin bleek dat de
  microfoon op speakers 29% van de tegenpartij meeving. Live mixen had dat onherstelbaar gemaakt;
- geen apparaatnamen of node-id's -- node-id's verschoven tijdens het testen daadwerkelijk vanzelf;
- geen klokdrift (gemeten 10,666 / 10,667 ms, constant);
- rauw opnemen, comprimeren en transcriberen pas ná het gesprek.

**Buiten scope gebleven, bewust:** `nixos-js5l` (automatische call-detectie) blijft draft/deferred
-- het mechanisme is uitgezocht en vastgelegd, de vorm is een keuze die niet gemaakt is. En acp63
in PipeWire krijgen is een losse kwestie.

**Nevenopbrengst.** De switch die hierbij hoorde legde een latent defect bloot: de `unstable`-input
pinde atuin 18.19.0 terwijl de draaiende generatie 18.21.0 gebruikte en de history-database al had
gemigreerd, waardoor elke switch de terminal sloopte. Opgelost in `15a4cc2`. De dode
root-`configuration.nix` die tijdens het onderzoek twee keer voor verwarring zorgde is weg in
`97c637a`.
