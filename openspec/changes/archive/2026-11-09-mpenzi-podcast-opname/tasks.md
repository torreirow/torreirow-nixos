# Tasks

## 1. Basis: vaste namen per poort

- [x] 1.1 Vastleggen welke eigenschap het poortpad draagt en hoeveel capture-kanalen de Capsule heeft; verificatie: notitie in design.md, besluit 2 (`device.bus-path` bewezen in de VM-test; Capsule mono volgens `/proc/asound`; `pw-dump` in Maaikes sessie volgt in 6.1)
- [x] 1.2 `modules/podcast-opname/` met `toorren.podcast.{enable, mic1Path, mic2Path}` en de WirePlumber-regel (`node.name` `podcast-mic-1/2`, beschrijving "Podcast mic 1/2"); importeren en aanzetten in `hosts/mpenzi/configuration.nix` met de gemeten paden; verificatie: `nix build .#nixosConfigurations.mpenzi.config.system.build.toplevel` slaagt

## 2. Route B: virtuele stereobron

- [x] 2.1 combine-stream-source `podcast-2mics` ("Podcast (2 mics)") met mic 1 op FL en mic 2 op FR, elk mono; verificatie: mpenzi bouwt en de PipeWire-config bevat de module
- [x] 2.2 ALSA-PCM `podcast` (type pipewire, `capture_node "podcast-2mics"`, met `hint`) in `/etc/alsa/conf.d/`; verificatie: `arecord -L` toont `podcast` en `arecord -D podcast -c 2` levert 2 kanalen (VM-test)

## 3. Audacity-seed

- [x] 3.1 Op mpenzi (als maaike, via RustDesk) in Audacity handmatig `podcast` + 2 kanalen kiezen en de resulterende `[AudioIO]`-sleutels uit `audacity.cfg` vastleggen; verificatie: test-opname in Audacity heeft mic 1 links en mic 2 rechts
- [x] 3.2 Minimale Audacity-seed (`audacityCfg` in `seeds.nix`, alleen `[AudioIO]`) en `herstel-app`; verificatie: `modules/maaike-apps_vmtest.nix` uitgebreid met de Audacity-seed en `herstel-app maaike audacity`, test slaagt

## 4. Route A: podrec

- [x] 4.1 `podrec start|stop|status` als `writeShellApplication`: controle op beide nodes, één `pw-record` van `podcast-2mics`, bij stop gesplitst naar `~/Podcast/<datum>_<tijd>/mic{1,2}.flac`, pidfile, stop met SIGINT, `notify-send`; verificatie: shellcheck via de build
- [x] 4.2 Menu-items "Podcast opname starten" en "Podcast opname stoppen" via `makeDesktopItem`; verificatie: `.desktop`-bestanden in de systeem-closure
- [x] 4.3 Unit-test met stub-`pw-record`/`pw-dump`: start maakt map en één opnemer, stop splitst links/rechts, tweede start weigert, ontbrekende mic 2 geeft melding en geen opname, stop sluit af; als flake check `checks.x86_64-linux.podrec`

## 5. Integratietest

- [x] 5.1 VM-test `modules/podcast-opname/vmtest.nix` met `snd-aloop`-bronnen en overschreven poortpaden: nodes heten `podcast-mic-1/2`, `podcast-2mics` heeft 2 kanalen, `podrec` levert twee FLAC-bestanden; als flake check `checks.x86_64-linux.podcast-opname`

## 6. Live op mpenzi

- [x] 6.1 Deploy mpenzi; met beide Capsules: Plasma toont "Podcast mic 1/2" en "Podcast (2 mics)"; verwisselen van de microfoons houdt de namen per poort
- [x] 6.2 Route B: Audacity-opname van 1 minuut, stereo splitsen, stem van mic 1 alleen links; volumeschuif mic 2 omlaag maakt alleen rechts zachter
- [x] 6.3 Route A: `podrec`-opname van 10 minuten via het menu; twee FLAC-bestanden, even veel samples (`soxi -s`); met één microfoon eruit meldt start welke ontbreekt

## 7. Documentatie

- [x] 7.1 `docs/podcast-mpenzi.md` (poortindeling, beide routes, uitleg voor Maaike, probleemoplossing) en indexregel in `CLAUDE.md`; `docs/maaike-app-defaults.md` tabel aangevuld met Audacity; verificatie: links kloppen

## Workflow follow-up

- Archiveren met `openspec archive mpenzi-podcast-opname -y` na live-acceptatie (groep 6).
