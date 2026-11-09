# Podcast opnemen op mpenzi

Twee NZXT Capsule USB-microfoons, elke stem op een eigen spoor. Module `modules/podcast-opname/`
(`toorren.podcast`), OpenSpec `podcast-recording`, change `mpenzi-podcast-opname`.

## Poortindeling

Beide Capsules hebben hetzelfde serienummer (`A00017:15:54`), dus alleen de USB-poort
onderscheidt ze. Beide poorten zitten aan de **rechterkant** van de laptop:

| Poort (rechts)             | udev `ID_PATH`                    | Naam in Plasma | Kanaal |
|----------------------------|-----------------------------------|----------------|--------|
| Dichtst bij het scherm     | `pci-0000:04:00.3-usb-0:2:1.0`    | Podcast mic 1  | links  |
| Dichtst bij de gebruiker   | `pci-0000:04:00.4-usb-0:2:1.0`    | Podcast mic 2  | rechts |

De microfoons zelf zijn verwisselbaar; de poort bepaalt de naam. Een Capsule in een andere poort
of via een hub krijgt geen podcastnaam en verschijnt als gewone "NZXT USB MIC".

## Twee routes

**Route B: Audacity** (wat Maaike gewend is)

1. Audacity openen; de seed zet apparaat `podcast` ("Podcast (2 mics)") en 2 kanalen klaar.
2. Opnemen. Links = mic 1, rechts = mic 2.
3. Na de opname: spoormenu (pijltje bij de spoornaam) > **Stereospoor splitsen naar mono**.

**Route A: opnameknop**

1. Menu > **Podcast opname starten**. Een melding bevestigt de start.
2. Menu > **Podcast opname stoppen**. Resultaat: `~/Podcast/<datum>_<tijd>/mic1.flac` en
   `mic2.flac`, die je in Audacity sleept.

Ontbreekt een microfoon, dan start er niets en zegt de melding welke. In een terminal:
`podrec start|stop|status`.

Beide routes nemen één stereostream op (`podcast-2mics`), dus de sporen lopen sample-exact gelijk.
`podrec` splitst die bij het stoppen met `sox`.

## Volume en koptelefoon

- **Volume per microfoon:** Plasma > geluid > invoerapparaten, schuif van "Podcast mic 1" of "2".
  Werkt voor beide routes. Richtwaarde: pieken in Audacity rond -12 dB, nooit rood.
- **Koptelefoon:** elke Capsule heeft een eigen koptelefoonaansluiting met directe monitoring;
  mpenzi hoeft daar niets voor te doen.
- **Standaardapparaten:** de Capsules (microfoon én koptelefoonuitgang) hebben een lage
  prioriteit, zodat laptopspeakers en -microfoon standaard blijven. Zonder die regel schakelde
  Plasma bij het aansluiten naar de Capsule, en verdween al het geluid naar de koptelefoonuitgang
  van mic 1 (gezien op 2026-11-05).

## Noise gate en nabewerking

Niet tijdens de opname, wel achteraf per spoor in Audacity:

- Een gate tijdens de opname knipt onherroepelijk stukjes weg (zachte woordeinden, adem). Achteraf
  kun je de drempel per stem bijstellen en ongedaan maken.
- Twee aparte sporen maken het makkelijk: per spoor **Effect > Noise Gate** (of eerst
  **Ruisonderdrukking** met een stil stuk als ruisprofiel). Zo dempt de gate ook de overspraak van
  de andere spreker op elke microfoon.
- Volgorde die meestal werkt: ruisonderdrukking > noise gate > compressor > normaliseren.

## Hoe het werkt

1. **WirePlumber-regel** op `device.bus-path` geeft het apparaat `device.name =
   alsa_card.podcast-mic-N`; een tweede regel hernoemt de invoer naar `podcast-mic-N`.
2. **PipeWire combine-stream** `podcast-2mics` ("Podcast (2 mics)"): mic 1 op FL, mic 2 op FR.
3. **ALSA-apparaat `podcast`** (`/etc/alsa/conf.d/60-podcast.conf`) wijst naar `podcast-2mics`;
   Audacity ziet PipeWire-bronnen anders niet los.
4. **Audacity-seed** in `home/profiles/maaike/seeds.nix`; terugzetten met
   `ssh wtoorren@10.77.0.3 sudo herstel-app maaike audacity`.

## Testen

```bash
nix build .#checks.x86_64-linux.podrec -L           # podrec met nep-PipeWire, links/rechts splitsen
nix build .#checks.x86_64-linux.podcast-opname -L   # VM met snd-aloop: namen, stereobron, podrec
```

De VM-test neemt stilte op: een toon via `snd-aloop` laat PipeWire in de VM vastlopen.

## Probleemoplossing

| Symptoom                                   | Oorzaak / oplossing                                           |
|--------------------------------------------|---------------------------------------------------------------|
| "Podcast (2 mics) ontbreekt"               | PipeWire draait nog van vóór de deploy: laptop herstarten, of `systemctl --user restart pipewire pipewire-pulse wireplumber` als maaike (uitloggen is niet genoeg) |
| Opname is stil                              | Dempknop bovenop de Capsule; volumeschuif in Plasma op 0/gedempt |
| Geen geluid uit de speakers                | Standaarduitvoer staat op "Podcast mic N koptelefoon"; terugzetten in Plasma |
| "Podcast mic 2 niet gevonden"              | Mic zit niet in de poort bij de gebruiker (rechts), of via hub |
| In Audacity geen `podcast` in de lijst     | Audacity-host op ALSA zetten; `arecord -L \| grep podcast`    |
| Beide stemmen op één kanaal                | Opname in mono; in Audacity 2 kanalen kiezen                  |
| Nieuwe poortpaden (andere laptop)          | `udevadm info -q property /dev/snd/controlC<N> \| grep ID_PATH` |
