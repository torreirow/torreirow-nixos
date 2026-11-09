## Context

De NixOS laptop (lobos, Lenovo ThinkPad P16s Gen2, AMD) draait GNOME 49.2 op Wayland met PipeWire als audio server. PulseAudio is uitgeschakeld. De Nektar Impact GX61 wordt al herkend door PipeWire als MIDI device (kaart 6, "Impact GX61 MIDI1/MIDI2 capture"). Er is geen externe audio interface aanwezig: output verloopt via het dockingstation (KT USB Audio, kaart 3) naar de PA mixer.

Huidig probleem: geen synthesizer software aanwezig, geen latency tuning, geen JACK support. De standaard PipeWire buffer (quantum) is ~1024 frames (~21ms bij 48kHz), te hoog voor live spelen met een band.

## Goals / Non-Goals

**Goals:**
- FluidSynth draaien met Salamander Grand Piano soundfont
- Latency onder de 12ms houden (menselijke waarnemingsgrens)
- Eenvoudig opstarten via één commando (`piano`)
- Geen verstoring van bestaande audio setup (Sandberg microfoon, Strawberry)
- Soundfont reproduceerbaar ophalen via Nix (fetchurl)

**Non-Goals:**
- DAW of opnamefunctionaliteit
- Meerdere instrumentklanken / patch-wisseling tijdens gebruik
- JACK als standalone server (PipeWire-JACK bridge volstaat)
- Automatisch starten bij login (handmatig starten is gewenst voor bewust gebruik)

## Decisions

### 1. FluidSynth direct, geen GUI (qsynth)
FluidSynth wordt via de commandline gestart door het `piano` script. qsynth voegt geen meerwaarde toe voor dit use case en vereist extra klik-handelingen. Het script encapsuleert alle parameters.

**Alternatief overwogen:** qsynth (GUI) - afgewezen omdat het complexer is en niet nodig voor één soundfont.

### 2. PipeWire-JACK bridge, geen standalone JACK
`services.pipewire.jack.enable = true` activeert de PipeWire JACK-compatibiliteitslaag. FluidSynth gebruikt dan `-a jack` als audio driver. Dit geeft lage latency zonder een aparte JACK daemon (jackd) te moeten starten of beheren.

**Alternatief overwogen:** pipewire met `-a pipewire` driver - beschikbaar maar minder stabiel voor lage latency dan de JACK bridge.

### 3. PipeWire quantum via environment variabele
`PIPEWIRE_LATENCY=256/48000` (~5.3ms) meegeven aan FluidSynth via het `piano` script. Dit forceert de quantum alleen voor die sessie zonder globale PipeWire config te wijzigen, zodat normale audio (Spotify, video) niet beïnvloed wordt.

**Alternatief overwogen:** Globale wireplumber quantum config - afgewezen omdat dit de hele audio stack vertraagt en Strawberry/browsers trager maakt.

### 4. Salamander Grand Piano via fetchurl derivation
De Salamander Grand Piano v3 SF2 is niet in nixpkgs beschikbaar maar wel gratis downloadbaar. Een custom Nix-derivation met `fetchurl` en de bekende hash maakt het reproduceerbaar en declaratief. Het soundfont bestand komt terecht in de Nix store en is via een symlink of direct pad beschikbaar.

**Alternatief overwogen:** `soundfont-fluid` (in nixpkgs) - prima kwaliteit maar duidelijk minder realistisch pianogeluid dan Salamander.

### 5. Helper script `piano` als systeem package
Een shell script dat FluidSynth start met de juiste parameters (driver, soundfont pad, latency, channel 1 = piano). Beschikbaar als `piano` commando voor alle gebruikers. Parameters hardcoded want er is één use case.

## Risks / Trade-offs

- **KT USB Audio latency** → Goedkope USB audio chips hebben soms hoge interrupt latency. Mitigatie: testen met `piano` en bij problemen quantum verder verlagen of externe USB audio interface aanschaffen.
- **fetchurl hash** → Als de Salamander download URL wijzigt, breekt de build. Mitigatie: hash pinnen op bekende versie, eventueel mirror toevoegen.
- **PipeWire JACK bridge stabiliteit** → Bij crashes van FluidSynth of JACK bridge kan het nodig zijn PipeWire te herstarten. Mitigatie: `systemctl --user restart pipewire` in README documenteren.
- **Quantum 256 frames** → Op sommige systemen geeft dit xruns (audio dropouts) bij hoge CPU load. Mitigatie: script biedt fallback naar 512 frames als comment in script.

## Migration Plan

1. Module toevoegen aan imports in `configuration.nix`
2. `nixos-rebuild switch --flake .#lobos`
3. Testen: keyboard aansluiten → `piano` uitvoeren → noot indrukken → geluid horen
4. Rollback: import verwijderen + rebuild

Geen datamigratie nodig. Geen bestaande services geraakt.

## Open Questions

- Werkt de KT USB Audio (dockingstation) stabiel bij quantum 256? Eventueel testen met 512.
- Wil je in de toekomst ook orgel/pad klanken? Dan zou Carla plugin host een uitbreiding zijn.
