# cckafe-photos Specification

## Purpose

De foto's van een meet-up staan in een Immich-album en verschijnen op de detailpagina van die
meet-up op cckafe.com. De dienst op malandro schrijft daarvoor alleen een manifest per album;
de foto's zelf blijven in Immich en worden door nginx via de API aan de bezoeker gegeven. De
albums zijn niet publiek: er bestaat geen share-link en de API-sleutel verlaat de server nooit.

## Requirements

### Requirement: De dienst schrijft alleen een manifest

De fotodienst SHALL per meet-up één `manifest.json` schrijven met per foto de asset-id, de
afmetingen en de wijzigingstijd. De dienst SHALL de foto's niet downloaden, niet verkleinen
en niet op schijf bewaren. De dienst SHALL op een timer draaien en SHALL handmatig gestart
kunnen worden.

#### Scenario: Album verwerken

- **WHEN** de fotodienst een meet-up met een bestaand album verwerkt
- **THEN** schrijft hij een manifest met de asset-id's van dat album en staan er geen
  fotobestanden in de fotomap

#### Scenario: Afmetingen kloppen met de preview

- **WHEN** een foto van 2400×1600 in het manifest belandt
- **THEN** noemt het manifest 1200×800, omdat de preview een korte zijde van 800 heeft

#### Scenario: Handmatig starten

- **WHEN** de fotodienst handmatig wordt gestart
- **THEN** worden de albums verwerkt zoals bij een timerstart

### Requirement: Nginx serveert de foto's uit Immich

Nginx SHALL een verzoek om `/immich/<asset-id>.webp` doorsturen naar
`/api/assets/<asset-id>/thumbnail?size=preview` op de lokale Immich, met de API-sleutel in
een header. De sleutel SHALL uit een age-secret komen en SHALL niet in de nix-store, de
HTML of het antwoord naar de browser terechtkomen. Er SHALL geen share-link worden
aangemaakt.

#### Scenario: Bezoeker vraagt een foto op

- **WHEN** de browser een foto uit de galerij opvraagt
- **THEN** antwoordt nginx met de WebP uit Immich en bevat het antwoord geen API-sleutel

#### Scenario: Immich is onbereikbaar

- **WHEN** Immich niet antwoordt
- **THEN** geeft de foto-URL een foutstatus en werkt de rest van de pagina normaal

### Requirement: Een ontbrekend album laat het vorige manifest staan

De fotodienst SHALL een meet-up waarvan het album niet bestaat of leeg is overslaan, zonder
het bestaande manifest te verwijderen. Een mislukte run SHALL geen half manifest opleveren.

#### Scenario: Album ontbreekt

- **WHEN** het album van een meet-up niet gevonden wordt
- **THEN** blijft het vorige manifest staan en meldt de dienst het album als niet gevonden

#### Scenario: Onderbroken run

- **WHEN** de dienst stopt voordat alle albums verwerkt zijn
- **THEN** staat er per album een volledig manifest of het vorige manifest
