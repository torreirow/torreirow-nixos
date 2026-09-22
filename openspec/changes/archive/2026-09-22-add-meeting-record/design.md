# Design: meeting-record

Alle besluiten hieronder zijn op lobos gemeten, niet aangenomen. Waar iets niet gemeten kon
worden staat dat er expliciet bij.

## Beslissing 1: twee sporen, geen live mix

Een meeting bestaat uit twee stromen die elkaar nooit raken:

```
   de anderen ──▶ app ──▶ sink ──▶ monitor ──▶ anderen.wav
   jouw stem  ──▶ mic ──▶ app ──▶ het netwerk in
                   └──────────────────────────▶ ik.wav
```

Teams, Slack en Jitsi spelen de eigen microfoon niet terug naar de sink (dat zou echoën), dus
één opnamepunt kan nooit beide kanten vangen.

Gekozen: **twee losse bestanden**, nooit live gemengd. Winst:

- niveaus achteraf corrigeerbaar (de eigen stem is doorgaans veel harder);
- zat je op speakers, dan hoort je mic de anderen mee en staan die dubbel in een mix — met losse
  sporen is dat achteraf te redden, in een live mix niet;
- whisper leest de sporen los → sprekerscheiding zonder diarisatiemodel. Dit is de hoofdreden.

## Beslissing 2: geen apparaatnamen of node-id's in het script

De inkomende kant via:

```
pw-record -P '{ stream.capture.sink=true }' anderen.wav
```

WirePlumber koppelt die stream zelf aan de monitor van de *huidige* default sink. Live
geverifieerd — `pw-link -l` tijdens een proefopname:

```
meetrec-probe:input_FL  |<- alsa_output.usb-KTMicro_...iec958-stereo:monitor_FL
meetrec-probe:input_FR  |<- alsa_output.usb-KTMicro_...iec958-stereo:monitor_FR
```

De eigen kant via kale `pw-record` → default source. Beide zijn gewone streams zonder vast doel,
dus ze verhuizen mee met een device-wissel.

Dat is op deze host geen luxe: er zijn vijf sinks, `hosts/lobos/midi.nix` zet de default actief
om naar KT USB, en er is een Bluetooth-headset (`bluez_output.98_29_EA_63_46_4C`). Een script dat
één keer bij het starten een node-id resolvet, verliest de opname bij de eerste wissel.

## Beslissing 3: klokdrift is geen probleem (gemeten)

Twee onafhankelijke `pw-record`-processen, één toon, twee meetpunten:

| Meetpunt     | opnemer A  | opnemer B  | verschil  |
|--------------|------------|------------|-----------|
| eerste flank | 3.773062 s | 3.762396 s | 10.666 ms |
| tweede flank | 3.942292 s | 3.931625 s | 10.667 ms |

Constante offset van ~10,7 ms, identiek tot op de microseconde over beide meetpunten: geen
oplopende drift. PipeWire hersampelt elk apparaat naar één grafiekklok, anders dan losse
ALSA-captures.

**Kanttekening:** beide opnemers hingen in die test aan dezelfde bron. Mic en monitor lopen in
de praktijk over twee verschillende USB-klokken. Het hersamplen naar de grafiekklok zou dat
gelijk moeten trekken; dat is niet over een volledig uur geforceerd getest (bean `nixos-4dd0`).

Gevolg: achteraf mixen is legitiem. Een offset van 11 ms is ruim onder wat hoorbaar is.

## Beslissing 4: speakervolume zit niet in de opname

`monitor.channel-volumes` is op de sink niet gezet → PipeWire-default `false`. Monitor- en
playbackvolume zijn losse regelaars (`monitorVolumes` is een eigen `Props`-parameter). Je
opname wordt dus niet stiller als je je speakers zachter zet.

## Beslissing 5: WAV tijdens de opname, Opus erna

Encoden tijdens de call is een verkeerde ruil. De 7840U in deze ThinkPad zakt onder aanhoudende
last van ~5041 naar ~3418 MHz (zie change `throttle-nix-builds`), en een encoder draait op
normale prioriteit — die concurreert dus rechtstreeks met de meeting. `pw-record` naar rauwe WAV
kost vrijwel niets.

Bij `stop` wordt geëncodeerd naar Opus (32 kbit/s mono), met `nice`/`ionice`. Dat is ~15 MB/uur
in plaats van ~350 MB/uur, en meteen het formaat dat whisper wil. De WAV wordt pas verwijderd
nadat de encoding is geslaagd.

## Beslissing 6: systeemgeluid loopt mee — geaccepteerd

Het inkomende spoor is de monitor van de default sink en bevat dus ook mpv/Strawberry,
Signal-belgeluiden en notificaties.

Het alternatief (per-app aftappen via een eigen null-sink of `pw-link` op de app-poorten) houdt
die eruit, maar Electron-apps maken bij elke call een nieuwe node aan, dus de links moeten elke
keer opnieuw gelegd worden. Prijs te hoog voor wat het oplevert.

## Verworpen alternatieven

- **Alleen de default output.** Simpelst, maar de eigen stem ontbreekt volledig. Afgewezen:
  beide kanten zijn expliciet gewenst.
- **Live mixen in PipeWire** (null-sink `MeetRec` + twee `pw-loopback`'s + `pw-record --target`).
  Levert één sample-synchroon bestand, maar vier objecten in plaats van twee, en een echte
  terugkoppellus zodra `MeetRec` per ongeluk de default sink wordt: de
  `stream.capture.sink=true`-loopback vangt dan zijn eigen monitor. Geen winst boven achteraf
  mixen, dat door beslissing 3 gedekt is.
- **`acp63` / `hw:2,0`** (de ingebouwde dekselmic van de P16s Gen 2). Capture-only DMIC-array.
  Kaart 2 heeft geen PipeWire-node: WirePlumber logde bij boot precies één mislukte kaart
  (`SPA handle 'api.alsa.acp.device' could not be loaded`), en alle bestaande nodes mappen op
  kaart 0/1/3/5/6. Onbereikbaar voor `pw-record`; rauw `arecord -D hw:2,0` is exclusieve toegang
  en bleek bezet (`Device or resource busy`, owner audacity pid 1552050). Levert bovendien alleen
  een slechte far-field versie van de eigen stem, nooit de inkomende kant. Acp63 in PipeWire
  krijgen is bewust geen onderdeel van deze change.
- **OBS.** Alleen zinnig zodra er ook beeld mee moet.
- **`pactl` / `sox`.** Staan niet op lobos. Niet toevoegen voor iets dat `pw-*` en ffmpeg al doen.

## Beslissing 7: transcriptie met sprekerlabels uit de sporen

`meetrec transcribe` draait whisper per spoor naar SRT en voegt die samen op tijdstempel, met
een label per regel (`[ik]` / `[anderen]`). Het samenvoegen gebeurt in een los python-script
(`merge-transcripts.py`), zoals `home/module/remarkable-sync/export.py`.

Sprekerscheiding komt dus uit de opnamestructuur, niet uit een diarisatiemodel. Dat is precies
waarom beslissing 1 niet live mixt.

Modelkeuze blijft een optie (`whisperModel`): `openai-whisper` staat al op de host, maar
`whisper-cpp` en `whisper-ctranslate2` zitten ook in nixpkgs en zijn op CPU een andere orde.
Meten, niet aannemen.

## Niet in deze change

- **Automatische call-detectie** (bean `nixos-js5l`, draft/deferred). PipeWire kan het: een
  `Stream/Input/Audio`-node betekent dat een app nú de microfoon afneemt, en
  `application.process.binary` geeft betrouwbaar `slack` / `electron` / `firefox` (waar
  `application.name` voor alle Electron-apps "Chromium input" zegt). Maar de vorm — handmatige
  `watch`-lus versus een altijd draaiende user service — is een bewuste keuze die nog niet
  gemaakt is, en een dienst die ongevraagd elk gesprek opneemt is geen detail.
- **`acp63` in PipeWire krijgen.** Losse kwestie, eigen change waard.
