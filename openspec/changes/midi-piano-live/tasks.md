## 1. Salamander soundfont derivation

- [x] 1.1 Zoek de officiële download URL en SHA256 hash van Salamander Grand Piano v3 SF2
- [x] 1.2 Schrijf een Nix fetchurl derivation voor de Salamander soundfont in `hosts/lobos/midi.nix`

## 2. Nieuwe module hosts/lobos/midi.nix

- [x] 2.1 Maak `hosts/lobos/midi.nix` aan met `security.rtkit.enable = true`
- [x] 2.2 Voeg `services.pipewire.jack.enable = true` toe aan de module
- [x] 2.3 Voeg `pkgs.fluidsynth` toe aan `environment.systemPackages`
- [x] 2.4 Voeg de Salamander soundfont derivation toe aan `environment.systemPackages`
- [x] 2.5 Schrijf het `piano` helper script als `pkgs.writeShellScriptBin` met PIPEWIRE_LATENCY=256/48000, `-a jack` driver, en het soundfont pad
- [x] 2.6 Voeg het `piano` script toe aan `environment.systemPackages`

## 3. Integratie in lobos configuratie

- [x] 3.1 Voeg `./midi.nix` toe aan de imports in `hosts/lobos/configuration.nix`

## 4. Testen

- [x] 4.1 Voer `sudo nixos-rebuild switch --flake .#lobos` uit en controleer op fouten
- [x] 4.2 Sluit de Impact GX61 aan en voer `piano` uit
- [x] 4.3 Druk een toets in op het keyboard en controleer of pianogluid hoorbaar is via de dockingstation audio output
- [x] 4.4 Controleer latency: speel een reeks noten en beoordeel of de vertraging acceptabel is voor live gebruik
