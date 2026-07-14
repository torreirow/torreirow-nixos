## MODIFIED Requirements

### Requirement: NixOS deployt HA template bestanden
De NixOS `activationScript` in `modules/hassio/default.nix` SHALL alle YAML-bestanden uit `modules/hassio/templates/` kopiëren naar `/var/lib/homeassistant/templates/`, inclusief het nieuwe bestand `airco.yaml`.

#### Scenario: Deploy na nixos-rebuild
- **WHEN** `nixos-rebuild switch` wordt uitgevoerd op malandro
- **THEN** bestaat `/var/lib/homeassistant/templates/airco.yaml` op het systeem

#### Scenario: Bestaande bestanden blijven intact
- **WHEN** `nixos-rebuild switch` wordt uitgevoerd
- **THEN** bestaat `/var/lib/homeassistant/templates/stookwijzer.yaml` nog steeds ongewijzigd
