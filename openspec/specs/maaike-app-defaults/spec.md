# maaike-app-defaults Specification

## Purpose
Herstelbare app-standaarden voor Maaike op mpenzi: seeds die niets overschrijven, `herstel-app`
om de standaard terug te zetten, de Spotify-login via agenix en browserextensies via policy.

## Requirements

### Requirement: home-manager voor maaike zonder Plasma-beheer
Het systeem SHALL voor `maaike` home-manager inschakelen via `toorren.maaike.enable`, met alleen
app-config. Het MUST GEEN Plasma-instellingen beheren en GEEN nixvim installeren.

#### Scenario: mpenzi bouwt met het profiel
- **WHEN** mpenzi gebouwd wordt
- **THEN** heeft maaike een HM-generatie zonder plasma-manager en zonder nixvim

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

### Requirement: Standaard terugzetten met herstel-app
Het systeem SHALL `herstel-app <gebruiker> <app|all>` bieden. Het MUST de app van die gebruiker
stoppen, het huidige bestand bewaren als `*.bak-<datum>` en de standaard terugzetten. Een
onbekende gebruiker of app MUST een foutmelding met de geldige keuzes geven.

#### Scenario: Nextcloud herstellen
- **WHEN** Wouter `sudo herstel-app maaike nextcloud` draait
- **THEN** is `nextcloud.cfg` weer de standaard en staat de oude versie als `nextcloud.cfg.bak-*`

#### Scenario: Onbekende app
- **WHEN** Wouter `sudo herstel-app maaike foo` draait
- **THEN** stopt het met een foutcode en noemt het de geldige apps

### Requirement: Spotify-login via agenix
Als `secrets/spotify-maaike.age` bestaat, SHALL mpenzi het ontsleutelen naar
`/home/maaike/.config/spotify/prefs` (owner maaike, 0600). Zonder het bestand MUST mpenzi gewoon
bouwen met een warning.

#### Scenario: Met secret
- **WHEN** `secrets/spotify-maaike.age` in de repo staat
- **THEN** heeft `age.secrets.spotify-maaike` dat pad, owner `maaike` en mode `0600`

### Requirement: Browserextensies via policy
mpenzi SHALL in Firefox en Chrome de Bitwarden- en uBlock-extensie afdwingen via systeempolicies.

#### Scenario: Policies
- **WHEN** de mpenzi-config geëvalueerd wordt
- **THEN** bevatten de Firefox-`ExtensionSettings` en de Chrome-`ExtensionInstallForcelist`
  Bitwarden en uBlock
