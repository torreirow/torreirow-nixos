## Why

De net opgeleverde `prefix + N`-binding switcht altijd naar de notepad-sessie. Handiger is een
**toggle**: één toets die heen-en-weer schakelt tussen de notepad-werkomgeving (`TorrLinny`) en
de hoofdsessie (`main`), zodat je met dezelfde toets terugkeert naar waar je vandaan kwam.

## What Changes

- `bind N` in `home/tmux.nix` wordt van een enkelrichtings-switch naar een **toggle**:
  - Zit je in `TorrLinny` → switch naar `main`.
  - Zit je elders → start `notepad` indien nodig en switch naar `TorrLinny`.
- De idempotente start-logica (`has-session TorrLinny || smug start notepad --detach`) en het
  gebruik van `switch-client` (geen popup) blijven ongewijzigd.

## Capabilities

### New Capabilities
<!-- Geen nieuwe capability. -->

### Modified Capabilities
- `tmux-notepad-binding`: De binding wordt een toggle tussen `TorrLinny` en `main` in plaats van
  een enkelrichtings-switch naar `TorrLinny`.

## Impact

- **Gewijzigd bestand**: `home/tmux.nix` (de `bind N`-regel).
- **Afhankelijkheden**: ongewijzigd (`smug`, `notepad.yml` → sessie `TorrLinny`). De `main`-sessie
  wordt door de bestaande `systemd.user.services.tmux` altijd aangemaakt.
- Activeren via `home-manager switch`.
