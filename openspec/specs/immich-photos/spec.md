# immich-photos Specification

## Purpose
Een eigen fotoserver op malandro die de foto's van de telefoon automatisch bewaart, inlogt via
Authelia en via API-sleutels foto's levert aan de reisapps, met de originelen versleuteld in S3.

## Requirements

### Requirement: Immich bereikbaar op photos.toorren.net
Het systeem SHALL Immich 3.x draaien via de NixOS-module `services.immich` (pakket en module uit
de `unstable`-input, omdat 26.05 alleen het onveilige 2.7.5 heeft), luisterend op
`127.0.0.1:2283`, en bereikbaar maken via nginx op `https://photos.toorren.net`. Er MUST GEEN
Authelia forward-auth voor de vhost staan, zodat de Immich-app, API-sleutels en deellinks werken.

#### Scenario: Webinterface bereikbaar
- **WHEN** iemand `https://photos.toorren.net/` opent
- **THEN** toont Immich zijn loginpagina, zonder omleiding naar `auth.toorren.net`

#### Scenario: API werkt met een sleutel
- **WHEN** een client `GET https://photos.toorren.net/api/server/ping` aanroept
- **THEN** antwoordt Immich met `{"res":"pong"}`

### Requirement: Inloggen via Authelia-OIDC
Het systeem SHALL een OIDC-client `immich` in Authelia hebben (policy `two_factor`) en Immich
SHALL OAuth-login via `https://auth.toorren.net` aanbieden, voor de webinterface en de
Android-app. Het client-secret MUST alleen versleuteld (agenix) in de repo staan en in Authelia
alleen als hash.

#### Scenario: Login via web
- **WHEN** de gebruiker op "Inloggen met Authelia" klikt en bij Authelia inlogt met 2FA
- **THEN** is hij ingelogd in Immich met zijn account

#### Scenario: Login via de Android-app
- **WHEN** de gebruiker in de Immich-app de server `https://photos.toorren.net` kiest en OAuth-login gebruikt
- **THEN** keert de app na Authelia terug en is de gebruiker ingelogd

### Requirement: Originelen versleuteld op een eigen JuiceFS-volume
Het systeem SHALL de originele foto's en video's opslaan op een JuiceFS-volume `immich`,
gemount op `/data/juicefs-immich`, met de metadata in PostgreSQL op malandro en de data onder
`s3://wto-s3-bucket/immich/`. De data MUST client-side versleuteld zijn. De S3-sleutels MUST
alleen toegang hebben tot het prefix `immich/`. Immich MUST NOT starten of schrijven als de
mount niet actief is.

#### Scenario: Upload komt in S3
- **WHEN** een foto wordt geüpload
- **THEN** staat het origineel onder `/data/juicefs-immich` en verschijnen nieuwe objecten onder `immich/` in de bucket

#### Scenario: Mount valt weg
- **WHEN** de JuiceFS-mountdienst stopt
- **THEN** stopt ook `immich-server`, en er komen geen bestanden in de onderliggende map

#### Scenario: Geen toegang buiten het prefix
- **WHEN** met de Immich-sleutels een object onder `juicefs/` of `rustic-backup/` wordt gelezen of geschreven
- **THEN** geeft S3 `AccessDenied`

### Requirement: Thumbnails en omgezette video lokaal
Het systeem SHALL thumbnails en omgezette video's op de lokale schijf
(`/data/external/immich`) bewaren en niet op JuiceFS.

#### Scenario: Thumbnail lokaal
- **WHEN** Immich een thumbnail maakt
- **THEN** staat die onder `/data/external/immich` en niet in S3

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

### Requirement: Reisapps koppelen via API-sleutel
Het systeem SHALL toestaan dat MarkMySteps en OwnSteps met een Immich-API-sleutel foto's
ophalen, los van de OIDC-login.

#### Scenario: MarkMySteps verbindt
- **WHEN** in MarkMySteps bij Instellingen → Immich de server-URL en een API-sleutel worden ingevuld
- **THEN** meldt MarkMySteps een geslaagde verbinding en zijn Immich-foto's te kiezen

### Requirement: Herstelbaar uit de backup
Het systeem SHALL de Immich-database meenemen in de nachtelijke database-dump en de
JuiceFS-metadata van het volume `immich` als `juicefs dump` meenemen in de rustic-backup. De
S3-bucket SHALL oude versies onder `immich/` 180 dagen bewaren (lifecycle-regel).

#### Scenario: Dumps aanwezig na een backup-run
- **WHEN** `rustic-backup.service` heeft gedraaid
- **THEN** bevat `/var/backup/db/pg-all.sql.zst` `CREATE DATABASE immich` en bestaat `/var/backup/db/juicefs-immich-meta-dump.json`

#### Scenario: Lifecycle-regels
- **WHEN** de lifecycle-configuratie van `wto-s3-bucket` wordt opgevraagd
- **THEN** staan zowel `juicefs-noncurrent-180d` als `immich-noncurrent-180d` erin

### Requirement: Zichtbaar in monitoring en documentatie
Het systeem SHALL Immich opnemen in de status-page en documenteren in `docs/immich.md`, met een
indexregel in `CLAUDE.md` en de poort in `PORTS.md`.

#### Scenario: Status-page
- **WHEN** `status.toorren.net` wordt geopend
- **THEN** staat Immich erop als gezond

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
