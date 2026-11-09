# Proposal

## Why

Op mpenzi wordt een podcast opgenomen met twee USB-microfoons (2x NZXT Capsule), elke stem op een
eigen spoor. Op Windows kon dat alleen met Voicemeeter en was het ingewikkeld. PipeWire op mpenzi
kan beide microfoons als losse bronnen op één klok aanbieden, maar zonder configuratie heten ze
allebei "NZXT USB MIC" (zelfde serienummer `A00017:15:54`) en kan Audacity maar één apparaat
tegelijk opnemen.

## What Changes

- Beide Capsules krijgen een vaste naam op basis van de USB-poort (rechterkant van de laptop):
  poort bij het scherm = "Podcast mic 1", poort bij de gebruiker = "Podcast mic 2".
- **Route B (Audacity):** een virtuele stereobron "Podcast (2 mics)" met links mic 1 en rechts
  mic 2. Audacity van Maaike staat standaard op die bron met 2 kanalen; na de opname splitst ze
  stereo naar twee mono-sporen.
- **Route A (opnameknop):** `podrec` met menu-items om te starten en te stoppen; neemt beide
  microfoons op als losse FLAC-bestanden in `~/Podcast/<datum-tijd>/` en meldt het als een
  microfoon ontbreekt.
- Volume per microfoon blijft live regelbaar met de gewone Plasma-schuiven; beide routes gebruiken
  dezelfde bronnen.
- Beide routes bestaan naast elkaar, zodat Maaike kan kiezen.

## Capabilities

### New Capabilities
- `podcast-recording`: opnemen van twee USB-microfoons als gescheiden sporen op mpenzi, met vaste
  naamgeving per USB-poort, een virtuele stereobron voor Audacity en een opnameknop.

### Modified Capabilities
- `maaike-app-defaults`: Audacity komt erbij als app met een standaard (seed + `herstel-app`).

## Impact

- `hosts/mpenzi/`: nieuwe audio-configuratie (WirePlumber-regel, PipeWire combine-stream) en het
  `podrec`-pakket met menu-items; of een eigen module onder `modules/`.
- `home/profiles/maaike/`: Audacity-seed (`audacity.cfg`) en `herstel-app`-ondersteuning.
- Nieuwe VM-test voor de naamgeving/bron en het `podrec`-script.
- Docs: nieuw `docs/podcast-mpenzi.md` plus indexregel in `CLAUDE.md`.
- Geen invloed op lobos/malandro; geen nieuwe secrets.
