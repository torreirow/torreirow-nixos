## Purpose

Beheerst hoeveel CPU-, I/O- en thread-budget nix-build-werk op een host mag opeisen, zodat builds
interactieve processen niet verdringen en de machine niet thermisch throttelt onder gelijktijdig
gebruik.

## ADDED Requirements

### Requirement: Build-werk wijkt voor interactieve processen

De nix-daemon op lobos SHALL zijn build-werk uitvoeren met CPU-scheduling die voorrang geeft aan
alle andere (interactieve) processen, zodat een lopende build gelijktijdige interactieve taken niet
laat vastlopen.

#### Scenario: Build tijdens interactief werk

- **WHEN** een `nix build` of `nixos-rebuild` build-fase draait terwijl de gebruiker in andere
  processen (zoals meerdere `claude-code`-sessies) actief is
- **THEN** krijgen die interactieve processen voorrang op CPU en blijven ze responsief, terwijl de
  build alleen de resterende CPU-capaciteit gebruikt

#### Scenario: Build op een verder inactieve machine

- **WHEN** een build draait en er geen noemenswaardige interactieve belasting is
- **THEN** mag de build de beschikbare CPU-capaciteit benutten en verloopt hij nagenoeg even snel
  als zonder throttling

### Requirement: Build-I/O verdringt interactieve I/O niet

De nix-daemon op lobos SHALL zijn schijf-I/O uitvoeren in een I/O-prioriteitsklasse die wijkt voor
interactieve I/O, zodat build-I/O op de versleutelde `/nix/store` gelijktijdige sessies niet blokkeert.

#### Scenario: Zware build-I/O tijdens interactief werk

- **WHEN** de build-fase veel naar de store schrijft terwijl de gebruiker actief is
- **THEN** krijgt interactieve I/O voorrang en merkt de gebruiker geen blokkerende I/O-wachttijden

### Requirement: Begrensd build-parallelisme

De host lobos SHALL het aantal gelijktijdige build-jobs en het aantal cores per job begrenzen, zodat
de gegenereerde threadhoeveelheid en daarmee de thermische piek onder het niveau blijft dat de
laptop-APU tot langdurige throttling dwingt.

#### Scenario: Parallelle build op de laptop-APU

- **WHEN** een build met meerdere te bouwen derivations start
- **THEN** draaien er hoogstens 6 jobs tegelijk met elk hoogstens 3 cores, waardoor het totale
  aantal build-threads en de thermische belasting begrensd blijven
