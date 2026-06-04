## Why

Er is behoefte aan een volwaardige MIDI piano setup op de NixOS laptop (lobos) zodat een Nektar Impact GX61 keyboard live ingezet kan worden in een kerkdienst naast gitarist, bassist en drummer. De benodigde software ontbreekt volledig en latency moet expliciet getuned worden voor live gebruik.

## What Changes

- Nieuwe NixOS module `hosts/lobos/midi.nix` met alle MIDI/audio software en configuratie
- FluidSynth synthesizer geinstalleerd als systeem package
- Salamander Grand Piano v3 soundfont beschikbaar via Nix-derivation (fetchurl)
- PipeWire quantum (buffer) ingesteld op ~256 frames (~5ms bij 48kHz) voor live latency
- `security.rtkit.enable = true` voor real-time audio prioriteit
- `services.pipewire.jack.enable = true` voor JACK-compatibele lage-latency output
- Helper script `piano` beschikbaar als systeem commando om FluidSynth direct te starten

## Capabilities

### New Capabilities

- `midi-piano`: MIDI keyboard → FluidSynth synthesizer pipeline met Salamander Grand Piano soundfont, geoptimaliseerd voor live gebruik via dockingstation audio output naar PA mixer

### Modified Capabilities

(geen bestaande specs geraakt)

## Impact

- **hosts/lobos/midi.nix**: nieuw bestand
- **hosts/lobos/configuration.nix**: import van midi.nix toevoegen
- **Packages**: fluidsynth, salamander-soundfont (custom derivation)
- **Services**: rtkit, pipewire-jack
- **PipeWire**: quantum/latency configuratie via wireplumber of environment variabele
- **Geen breaking changes** voor bestaande audio setup (Sandberg microfoon, Strawberry, etc.)
