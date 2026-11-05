## MODIFIED Requirements

### Requirement: Machine learning uit, video op de CPU
Het systeem SHALL de machine-learningdienst van Immich NIET op malandro draaien (de J3455 heeft
geen AVX), maar op lobos: alleen `immich-machine-learning` (zelfde versie als de server), op poort
3003, bereikbaar via de Nebula-mesh en alleen voor host `malandro`. Immich op malandro SHALL ML
gebruiken via `http://10.77.0.2:3003`. Video SHALL op de CPU worden omgezet
(`ffmpeg.accel = "disabled"`); VAAPI op de HD 500 is een vervolgtaak.

#### Scenario: Geen ML-dienst
- **WHEN** de diensten op malandro worden bekeken
- **THEN** draait er geen `immich-machine-learning`

#### Scenario: ML via lobos
- **WHEN** lobos aan is en malandro `http://10.77.0.2:3003/ping` aanroept
- **THEN** antwoordt de ML-dienst met `pong` en meldt Immich de ML-server als healthy

#### Scenario: ML-poort niet open buiten Nebula
- **WHEN** een ander apparaat op het LAN of een andere Nebula-host poort 3003 van lobos benadert
- **THEN** wordt de verbinding geweigerd of tegengehouden

#### Scenario: Lobos uit
- **WHEN** lobos uit staat of slaapt
- **THEN** blijft Immich werken (upload, bladeren); ML-taken mislukken en zijn later met "Ontbrekende" opnieuw te draaien

#### Scenario: Video wordt omgezet
- **WHEN** een video in een niet-ondersteund formaat wordt geüpload
- **THEN** maakt Immich een omgezette `.mp4` onder `/data/external/immich/encoded-video`
