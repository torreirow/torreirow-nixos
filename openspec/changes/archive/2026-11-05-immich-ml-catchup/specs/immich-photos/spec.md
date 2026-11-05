## ADDED Requirements

### Requirement: ML-werk inhalen als lobos terug is
Het systeem SHALL op malandro elke 10 minuten controleren of de ML-dienst op lobos bereikbaar is.
Wordt hij (weer) bereikbaar, of is de laatste start ouder dan 6 uur, dan SHALL het via de
Immich-API de jobs `smartSearch` en `faceDetection` starten met `force=false` (alleen ontbrekende
assets). De gebruikte API-sleutel MUST alleen het recht `job.create` hebben en MUST alleen
versleuteld (agenix) in de repo staan.

#### Scenario: Lobos komt terug
- **WHEN** de vorige controle ML onbereikbaar vond en ML nu `pong` antwoordt
- **THEN** start de timer de Missing-jobs voor slim zoeken en gezichtsdetectie

#### Scenario: Lobos is uit
- **WHEN** ML niet antwoordt
- **THEN** start de timer niets en onthoudt hij dat ML onbereikbaar was

#### Scenario: Geen onnodige starts
- **WHEN** ML bereikbaar blijft en de laatste start minder dan 6 uur geleden is
- **THEN** start de timer niets

#### Scenario: Sleutel ongeldig
- **WHEN** Immich de sleutel weigert
- **THEN** faalt de dienst (zichtbaar als failed unit)
