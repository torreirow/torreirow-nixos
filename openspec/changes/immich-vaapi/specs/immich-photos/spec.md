## RENAMED Requirements

- FROM: `### Requirement: Machine learning uit, video op de CPU`
- TO: `### Requirement: Machine learning op lobos, video via VAAPI`

## MODIFIED Requirements

### Requirement: Machine learning op lobos, video via VAAPI
Het systeem SHALL de machine-learningdienst van Immich NIET op malandro draaien (de J3455 heeft
geen AVX), maar op lobos: alleen `immich-machine-learning` (zelfde versie als de server), op poort
3003, bereikbaar via de Nebula-mesh en alleen voor host `malandro`. Immich op malandro SHALL ML
gebruiken via `http://10.77.0.2:3003`. Video SHALL via VAAPI op de HD 500 worden omgezet
(`ffmpeg.accel = "vaapi"`, `accelDecode = true`, driver iHD), met Immich's eigen terugval op
software-decode en daarna de CPU. Immich SHALL alleen toegang hebben tot `/dev/dri/renderD128`.
Het Immich-pakket MUST de patch bevatten die bij software-decode `format=nv12` vóór `hwupload`
zet.

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

#### Scenario: Omzetten via de GPU
- **WHEN** Immich een video omzet
- **THEN** logt hij "with VAAPI-accelerated encoding" en "Successfully encoded", zonder "Retrying with VAAPI acceleration disabled"

#### Scenario: Kleine of niet-hardware-decodeerbare bron
- **WHEN** de bron 720p of kleiner is, of de GPU hem niet kan decoderen (mpeg4, H.264 Baseline)
- **THEN** slaagt VAAPI-encoding na software-decode (dankzij `format=nv12`)
