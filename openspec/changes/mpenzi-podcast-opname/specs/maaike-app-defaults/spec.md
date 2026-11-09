# Spec Delta

## MODIFIED Requirements

### Requirement: Seeds overschrijven niets
Het systeem SHALL de standaardconfig van Nextcloud, Bitwarden, ZapZap, SMPlayer en Audacity als
gewoon, schrijfbaar bestand van de gebruiker neerzetten, en alleen als het bestand ontbreekt.

#### Scenario: Eerste activatie
- **WHEN** home-manager voor maaike voor het eerst activeert
- **THEN** bestaat `~/.config/Nextcloud/nextcloud.cfg` met `nxc.toorren.net` en `mtoorren`
- **AND** wijst `~/.config/Bitwarden/data.json` naar `https://vw.toorren.net`

#### Scenario: Gewijzigd bestand blijft staan
- **WHEN** maaike een seed-bestand heeft aangepast en home-manager opnieuw activeert
- **THEN** blijft haar versie staan

#### Scenario: Audacity staat op de podcastbron
- **WHEN** home-manager voor maaike activeert en Audacity nog geen config heeft
- **THEN** neemt Audacity standaard op van "Podcast (2 mics)" met 2 kanalen
- **AND** kan `sudo herstel-app maaike audacity` die standaard terugzetten
