## Why

De airco in de werkkamer wordt handmatig ingesteld via het HA dashboard, maar er is geen snelle manier om de optimale koeltemperatuur toe te passen. Met één klik op een knop moet de airco direct op de berekende adviestemperatuur (gebaseerd op buitentemperatuur) kunnen worden ingesteld.

## What Changes

- Nieuw NixOS-beheerd template bestand `modules/hassio/templates/airco.yaml` met sensor `sensor.airco_werkkamer_advies_temperatuur`
- NixOS `activationScript` in `modules/hassio/default.nix` uitgebreid om het nieuwe template te deployen
- HA script (via HA UI) dat de airco instelt op cool-modus met de adviestemperatuur
- Button card (via HA UI) op het bestaande Airco dashboard

## Capabilities

### New Capabilities

- `airco-advies-knop`: Template sensor die adviestemperatuur berekent (clamp(buiten − 4, 22°C, 25°C)), plus een script en dashboard-knop om de airco met één klik op die temperatuur in te stellen in cool-modus

### Modified Capabilities

- `hassio-templates`: NixOS activationScript in `modules/hassio/default.nix` wordt uitgebreid met deploy van `airco.yaml`

## Impact

- `modules/hassio/default.nix` — activationScript uitbreiding
- `modules/hassio/templates/airco.yaml` — nieuw bestand
- HA `scripts.yaml` en Airco dashboard — via HA UI (niet in git)
- Entiteit `sensor.airco_werkkamer_advies_temperatuur` wordt beschikbaar in HA na nixos-rebuild + HA herladen
