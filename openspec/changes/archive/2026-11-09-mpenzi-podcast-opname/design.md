# Design

## Context

- mpenzi draait PipeWire met pulse en alsa, WirePlumber, Plasma 6 (`hosts/mpenzi/configuration.nix`).
  Audacity staat in `hosts/mpenzi/apps.nix`.
- Gemeten op 2026-11-05 met beide Capsules aangesloten: vendor `1e71`, model `2606`, beide
  `ID_SERIAL_SHORT=A00017:15:54`, kaarten "NZXT USB MIC" op `ID_PATH`
  `pci-0000:04:00.3-usb-0:2:1.0` (bij het scherm) en `pci-0000:04:00.4-usb-0:2:1.0` (bij de
  gebruiker). Elke Capsule heeft ook een afspeeluitgang (koptelefoon, S24_3LE, 48/96 kHz).
- App-standaarden van Maaike lopen via seeds + `herstel-app` (`home/profiles/maaike/seeds.nix`,
  `modules/maaike-apps.nix`).
- `meetrec` op lobos (`home/module/meeting-record/`) neemt al twee sporen op met `pw-record`; het
  stop-via-SIGINT-patroon is herbruikbaar, de module zelf niet (home-manager, andere bronnen,
  whisper).

## Goals / Non-Goals

**Goals:**
- Eén module die de basis, route A en route B samen aanzet voor mpenzi.
- Alles declaratief; geen handwerk in pavucontrol of Audacity-voorkeuren.

**Non-Goals:**
- Monteren, normaliseren of een podcast-export maken.
- Live mixen of monitoring via de laptop (de Capsule heeft directe monitoring op de koptelefoon).
- Meer dan twee microfoons of andere poorten/hubs.

## Decisions

1. **Eigen module `modules/podcast-opname/`** met `toorren.podcast.{enable, mic1Path, mic2Path}`,
   geïmporteerd door mpenzi. De poortpaden zijn opties met de gemeten waarden als default in de
   host, zodat een andere laptop alleen paden hoeft te zetten.
   *Alternatief:* direct in `hosts/mpenzi/` — minder testbaar en niet herbruikbaar.

2. **Naamgeving met een WirePlumber-regel op `device.bus-path`** (`services.pipewire.wireplumber.extraConfig`,
   `monitor.alsa.rules`): het apparaat en zijn invoer-node krijgen `node.name` `podcast-mic-1`/`-2`
   en `node.description` "Podcast mic 1"/"2". Vaste `node.name` is nodig omdat beide anders
   `alsa_input.usb-NZXT_..._A00017_15_54-00...` heten met een volgorde-afhankelijk achtervoegsel.
   *Alternatief:* udev-regel die `ID_SERIAL` herschrijft — omslachtiger en raakt ook andere software.
   Uitgevoerd in twee stappen: de regel op `device.bus-path` zet `device.name` op
   `alsa_card.podcast-mic-N`, waardoor WirePlumber de invoer `alsa_input.podcast-mic-N.<profiel>`
   noemt; een tweede regel hernoemt die naar `podcast-mic-N`. Bewezen in de VM-test met
   `snd-aloop`. De Capsule neemt mono op (`/proc/asound/card3/stream0`: 1 kanaal, S24_3LE).

3. **Route B met `libpipewire-module-combine-stream`** (`combine.mode = source`), node
   `podcast-2mics`, beschrijving "Podcast (2 mics)", `audio.position = [ FL FR ]`; stream-regels
   koppelen `podcast-mic-1` aan FL en `podcast-mic-2` aan FR, elk als mono (PipeWire mixt een
   stereo-capture van de Capsule zelf naar mono). Omdat het de gewone mic-nodes als bron gebruikt,
   werken de Plasma-volumeschuiven per mic vanzelf.
   *Alternatief:* Voicemeeter-achtige virtuele mixer (loopback + filter-chain) — meer bewegende
   delen, zelfde resultaat.

4. **Audacity vindt de bron via een ALSA-PCM `podcast`** (`/etc/alsa/conf.d/`, type `pipewire`,
   `capture_node "podcast-2mics"`, met `hint` zodat hij in de lijst staat). Audacity (PortAudio)
   toont PipeWire-nodes niet los; een benoemde ALSA-PCM wel, en een seed kan er stabiel naar
   verwijzen (`RecordingDevice=podcast`, `RecordChannels=2` in `~/.config/audacity/audacity.cfg`).
   *Alternatieven:* de standaardmicrofoon omzetten (raakt Zoom/Jitsi), of WirePlumber de
   Audacity-stream laten onthouden (niet declaratief, breekt na herstel).

5. **Route A: `podrec` neemt de stereobron `podcast-2mics` op en splitst bij stop** met
   `sox ... remix 1` / `remix 2` naar `mic1.flac` en `mic2.flac`. `writeShellApplication`, pidfile
   in `$XDG_RUNTIME_DIR/podrec`, stop met SIGINT zodat het bestand netjes wordt afgesloten,
   `notify-send` voor meldingen. Vóór de start controleert het met `pw-dump` of beide mic-nodes
   bestaan. Menu-items "Podcast opname starten/stoppen" via `makeDesktopItem`.
   *Verworpen:* twee losse `pw-record`-processen, één per mic. In de VM-test startten die ~170 ms
   na elkaar, en dan lopen de stemmen in de montage niet gelijk. Eén stream is sample-exact.
   *Alternatief:* `meetrec` generaliseren — die is home-manager en meeting-specifiek.

6. **Audacity-seed in het bestaande seed-mechanisme**: een minimaal `audacity.cfg` in
   `home/profiles/maaike/defaults/`, toegevoegd aan de lijst in `seeds.nix` en aan `herstel-app`.

## Risks / Trade-offs

- [Capsule in andere poort of hub → geen podcastnaam] → `podrec` meldt welke mic ontbreekt; docs
  en stickers op de microfoons; poortpaden zijn opties.
- [Twee USB-klokken lopen uit elkaar] → PipeWire resamplet elke bron naar de graph-klok en beide
  routes nemen één stereostream op, dus de sporen zijn per definitie even lang. Acceptatie: na
  10 minuten klinken beide stemmen in Audacity nog gelijk (geen echo als je ze samen afspeelt).
- [Audacity toont de ALSA-PCM niet of kiest een ander kanaalaantal] → in taak 3 eerst handmatig
  verifiëren op mpenzi; terugval is de standaardbron tijdelijk op "Podcast (2 mics)" zetten.
- [Audacity-config-formaat verandert tussen versies] → seed minimaal houden (alleen `[AudioIO]`).
- [Geen echte USB-microfoon in een VM-test] → VM-test met `snd-aloop` als nep-bron en
  overschreven poortpaden voor de pijplijn (met stilte: een toon via aloop laat PipeWire in de VM
  vastlopen). Links/rechts toetst de unit-test bij het splitsen; de echte poortherkenning en een
  echte stem worden live op mpenzi getest.

## Migration Plan

Nieuwe functionaliteit, niets te migreren. Deploy vanaf lobos met de gewone mpenzi-deploy; terug
naar de vorige generatie als het audio op mpenzi verstoort (de module raakt alleen de twee
Capsules en voegt een virtuele bron toe).
