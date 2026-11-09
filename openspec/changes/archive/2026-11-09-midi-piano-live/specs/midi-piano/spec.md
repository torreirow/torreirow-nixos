## ADDED Requirements

### Requirement: FluidSynth synthesizer beschikbaar
Het systeem SHALL het `fluidsynth` package beschikbaar stellen als systeem package op lobos.

#### Scenario: FluidSynth aanwezig na rebuild
- **WHEN** `nixos-rebuild switch --flake .#lobos` succesvol is uitgevoerd
- **THEN** is het commando `fluidsynth --version` beschikbaar en toont het een versienummer

### Requirement: Salamander Grand Piano soundfont beschikbaar
Het systeem SHALL de Salamander Grand Piano v3 soundfont beschikbaar stellen via een Nix-derivation zodat deze na rebuild in de Nix store aanwezig is.

#### Scenario: Soundfont aanwezig in Nix store
- **WHEN** `nixos-rebuild switch --flake .#lobos` succesvol is uitgevoerd
- **THEN** bestaat het soundfont bestand op een bekend pad (bijv. `/run/current-system/sw/share/sounds/sf2/SalamanderGrandPiano.sf2` of via symlink)

#### Scenario: Soundfont is geldig SF2 bestand
- **WHEN** FluidSynth wordt gestart met het soundfont pad
- **THEN** laadt FluidSynth zonder foutmelding en rapporteert het soundfont als geladen

### Requirement: rtkit real-time audio prioriteit
Het systeem SHALL `security.rtkit.enable = true` hebben zodat audio processen real-time prioriteit kunnen aanvragen.

#### Scenario: rtkit actief na rebuild
- **WHEN** `nixos-rebuild switch --flake .#lobos` succesvol is uitgevoerd
- **THEN** draait de `rtkit-daemon.service` zonder fouten

### Requirement: PipeWire JACK bridge actief
Het systeem SHALL `services.pipewire.jack.enable = true` hebben zodat FluidSynth via de JACK audio driver verbinding kan maken met PipeWire.

#### Scenario: JACK bridge beschikbaar
- **WHEN** PipeWire draait na rebuild
- **THEN** is de JACK socket beschikbaar en kan FluidSynth starten met `-a jack` zonder foutmelding

### Requirement: Piano helper script
Het systeem SHALL een uitvoerbaar commando `piano` beschikbaar stellen dat FluidSynth start met de juiste parameters voor live gebruik.

#### Scenario: Piano commando beschikbaar
- **WHEN** `nixos-rebuild switch --flake .#lobos` succesvol is uitgevoerd
- **THEN** is het commando `piano` beschikbaar in PATH

#### Scenario: Piano start FluidSynth met lage latency
- **WHEN** het commando `piano` uitgevoerd wordt terwijl PipeWire draait
- **THEN** start FluidSynth met JACK audio driver, Salamander soundfont geladen, en PIPEWIRE_LATENCY ingesteld op 256/48000

#### Scenario: MIDI keyboard klinkt na starten piano
- **WHEN** het commando `piano` draait en de Impact GX61 aangesloten is
- **THEN** produceert het indrukken van een toets op het keyboard hoorbaar pianogluid via de audio output
