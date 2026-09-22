# meeting-record

Neemt **beide kanten** van een gesprek (Teams, Slack, Jitsi) op als twee gescheiden sporen.

```nix
services.meeting-record = {
  enable = true;
  # targetDir       = "~/Meetings";  # default
  # opusBitrate     = "32k";
  # mixWeights      = "1 1";         # volgorde: anderen ik
  # whisperModel    = "turbo";
  # whisperLanguage = "nl";
};
```

```bash
meetrec start [naam]       # begin een opname
meetrec status             # loopt er iets, sinds wanneer, aan welke bronnen
meetrec stop               # stop, comprimeer naar Opus, ruim de WAV's op
meetrec list               # afgeronde opnames
meetrec mix [map]          # voeg de twee sporen samen tot één bestand
meetrec transcribe [map]   # whisper per spoor + samengevoegd transcript
```

## Waarom twee sporen

Een gesprek bestaat uit twee stromen die elkaar nooit raken:

```
   de anderen ──▶ app ──▶ sink ──▶ monitor ──▶ anderen.opus
   jouw stem  ──▶ mic ──▶ app ──▶ het netwerk in
                   └──────────────────────────▶ ik.opus
```

Meeting-apps spelen je eigen microfoon **niet** terug naar de sink -- dat zou echoën. Eén
opnamepunt kan dus nooit beide kanten vangen: een opname van alleen de systeemuitvoer levert
"iedereen behalve jij" op.

De sporen worden niet live gemengd. Dat kost niets en levert drie dingen op:

- niveaus zijn achteraf te corrigeren (je eigen stem staat doorgaans veel harder);
- zat je op speakers, dan hoorde je mic de anderen mee en staan die dubbel in een mix -- met
  losse sporen is dat achteraf te redden;
- **whisper leest de sporen los, dus je krijgt sprekerscheiding zonder diarisatiemodel.** Dat is
  de hoofdreden.

`meetrec mix` maakt er alsnog één bestand van wanneer je dat wilt. De sporen blijven staan.

## Geen apparaatnamen in het script

De inkomende stream draagt `stream.capture.sink=true`; WirePlumber koppelt hem daarna zelf aan
de monitor van de *huidige* default sink. De mic-stream krijgt de default source. Er staat dus
nergens een node-id of een apparaatnaam.

Dat is op deze host geen luxe: er zijn vijf sinks, `hosts/lobos/midi.nix` zet de default actief
om naar KT USB, en er is een Bluetooth-headset. **Getest:** tijdens een lopende opname de default
sink omzetten en weer terugzetten -- het inkomende spoor verhuisde mee en weer terug, zonder
onderbreking.

## Wat er in de opname zit

Het inkomende spoor is de monitor van de default sink en bevat dus ook je overige systeemgeluid:
muziek, notificaties, een binnenkomend Signal-belletje. Dat is de prijs voor een opname die geen
apparaatnamen hoeft te kennen en een device-wissel overleeft.

Het alternatief (per-app aftappen via een eigen null-sink of `pw-link` op de app-poorten) houdt
die eruit, maar Electron-apps maken bij elke call een nieuwe node aan, dus de links moeten elke
keer opnieuw gelegd worden. Zie `openspec/specs/meeting-record/` en de gearchiveerde change
`add-meeting-record` voor de volledige afweging.

## Lopen de sporen niet uit elkaar?

Nee. Twee onafhankelijke `pw-record`-processen, gemeten met één toon op twee meetpunten:

| Meetpunt     | opnemer A  | opnemer B  | verschil  |
|--------------|------------|------------|-----------|
| eerste flank | 3.773062 s | 3.762396 s | 10.666 ms |
| tweede flank | 3.942292 s | 3.931625 s | 10.667 ms |

Constante offset van ~10,7 ms, identiek tot op de microseconde: geen oplopende drift. PipeWire
hersamplet elk apparaat naar één grafiekklok, anders dan losse ALSA-captures. Achteraf mixen is
daarom legitiem, en 11 ms is ruim onder hoorbaar.

## Rauw tijdens het gesprek, Opus erna

Tijdens de opname schrijft `pw-record` rauwe WAV (~350 MB/uur per spoor); dat kost vrijwel geen
CPU. Pas bij `meetrec stop` wordt er gecomprimeerd naar Opus 32k mono (~15 MB/uur), met
`nice`/`ionice`. De WAV verdwijnt pas nadat de compressie is geslaagd -- mislukt ze, dan blijft
het origineel staan en meldt het commando dat.

Encoden of transcriberen *tijdens* de call is een verkeerde ruil: deze 7840U zakt onder
aanhoudende last van ~5041 naar ~3418 MHz (zie change `throttle-nix-builds`), en beide draaien
op normale prioriteit -- ze concurreren dus rechtstreeks met je gesprek.

Gemeten op lobos: `whisper` met het `turbo`-model deed er **78 s** over voor 2 × 35 s audio op
CPU (~1,1× realtime per spoor). `whisper-cpp` en `whisper-ctranslate2` zitten ook in nixpkgs en
zijn een andere orde -- meten, niet aannemen.

## Het neemt nooit uit zichzelf op

`meetrec start` is altijd een expliciete handeling. Er is geen timer en geen dienst.

Automatische call-detectie is technisch goed te doen -- een `Stream/Input/Audio`-node betekent dat
een app nú de microfoon afneemt, en `application.process.binary` geeft betrouwbaar `slack` /
`electron` / `firefox` (waar `application.name` voor élke Electron-app "Chromium input" zegt) --
maar een dienst die ongevraagd elk gesprek opneemt is geen detail. Zie bean `nixos-js5l`.

## Testen

```bash
python3 home/module/meeting-record/merge_transcripts_test.py
```

Toetst het samenvoegen van de SRT's: volgorde, sprekerlabels, meerregelige blokken, een leeg
spoor en een ontbrekend spoor. Draait zonder whisper, audio of netwerk.

De rest van de module is shell-lijmwerk; dat wordt bij het bouwen door shellcheck gedekt
(`writeShellApplication`) en verder door een echte proefopname.

## Wat hier bewust niet gebruikt wordt

- **`acp63` / `hw:2,0`**, de ingebouwde dekselmic van de P16s Gen 2. Capture-only DMIC-array, en
  kaart 2 heeft géén PipeWire-node -- WirePlumber logt bij boot precies één mislukte kaart
  (`SPA handle 'api.alsa.acp.device' could not be loaded`). Onbereikbaar voor `pw-record`, en
  rauw `arecord -D hw:2,0` is exclusieve toegang. Levert bovendien alleen een slechte far-field
  versie van je eigen stem, nooit de inkomende kant.
- **`pactl` en `sox`** staan niet op lobos. Alles loopt via `pw-*` en ffmpeg.
