# hassio-templates Specification

## Purpose
Home Assistant-templates (template-sensoren) staan in de repo en worden bij elke `nixos-rebuild`
op malandro naar de configuratiemap van Home Assistant gekopieerd.

## Requirements

### Requirement: NixOS deployt HA template bestanden
De NixOS `activationScript` in `modules/hassio/default.nix` SHALL de template-bestanden uit `modules/hassio/templates/` (`stookwijzer.yaml` en `airco.yaml`) kopiëren naar `/var/lib/homeassistant/templates/`.

#### Scenario: Deploy na nixos-rebuild
- **WHEN** `nixos-rebuild switch` wordt uitgevoerd op malandro
- **THEN** bestaat `/var/lib/homeassistant/templates/airco.yaml` op het systeem

#### Scenario: Bestaande bestanden blijven intact
- **WHEN** `nixos-rebuild switch` wordt uitgevoerd
- **THEN** bestaat `/var/lib/homeassistant/templates/stookwijzer.yaml` nog steeds ongewijzigd
