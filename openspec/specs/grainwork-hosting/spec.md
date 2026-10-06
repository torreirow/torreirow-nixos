# grainwork-hosting Specification

## Purpose
Beschrijft hoe GrainWork op malandro wordt aangeboden: een certificaat voor `*.dutchyland.net`, Pocket ID als eigen identiteitsprovider en de site achter oauth2-proxy, zodat alleen uitgenodigde deelnemers de studies zien.

## Requirements

### Requirement: Wildcard-certificaat
Met `services.grainwork.enable` SHALL malandro een ACME-certificaat voor `*.dutchyland.net` en `dutchyland.net` aanvragen via de DNS-01-challenge, gedelegeerd naar Route53 via de CNAME `_acme-challenge.dutchyland.net`.

#### Scenario: Na de CNAME
- **WHEN** de CNAME bij OpenProvider staat en de configuratie actief is
- **THEN** serveren `grainwork.dutchyland.net` en `id.dutchyland.net` een geldig certificaat voor `*.dutchyland.net`

### Requirement: Pocket ID alleen via nginx
Pocket ID SHALL alleen op `127.0.0.1` luisteren en via nginx op `id.dutchyland.net` bereikbaar zijn, met de databaseverbinding en de encryption key uit agenix-bestanden.

#### Scenario: Geen directe poort
- **WHEN** Pocket ID draait
- **THEN** luistert poort 8098 alleen op `127.0.0.1`

### Requirement: Setup-slot
Zolang `pocketId.setupLock` aan staat (standaard), SHALL `id.dutchyland.net` alleen bereikbaar zijn vanaf het thuis-LAN, WireGuard en de server zelf; andere bezoekers krijgen 403.

#### Scenario: Van buitenaf tijdens de setup
- **WHEN** iemand van buiten het thuisnetwerk `https://id.dutchyland.net/setup` opent terwijl het slot aan staat
- **THEN** krijgt hij 403

### Requirement: Site alleen voor de groep grainwork
Met `site.enable` SHALL `grainwork.dutchyland.net` de bestanden uit `/var/www/grainwork` serveren, en SHALL elk verzoek zonder geldige sessie van een lid van de Pocket ID-groep `grainwork` worden doorgestuurd naar de login, zonder dat er inhoud wordt meegestuurd.

#### Scenario: Niet ingelogd
- **WHEN** iemand zonder sessie `/studies/nehemia/` opent
- **THEN** krijgt hij een redirect naar `/oauth2/start` en geen studie-inhoud

#### Scenario: Ingelogd zonder groep
- **WHEN** iemand met een Pocket ID-account maar zonder groep `grainwork` inlogt
- **THEN** krijgt hij geen toegang tot de site

### Requirement: Welkomstpagina zonder login
`/welkom/` en de statische assets (`/css/`, `/js/`, `/img/`, `/fontawesome/`, `/webfonts/`, `/style.main.*.css`, `/favicon.ico`, `/robots.txt`) SHALL zonder login bereikbaar zijn.

#### Scenario: Uitleg voor een nieuwe deelnemer
- **WHEN** iemand zonder account `/welkom/` opent
- **THEN** krijgt hij de welkomstpagina met opmaak (HTTP 200)

### Requirement: OIDC naar Pocket ID
oauth2-proxy SHALL Pocket ID op `id.dutchyland.net` als OIDC-provider gebruiken, met de scopes `openid email profile groups offline_access`, PKCE (S256), client-id en -secret uit een agenix-env-bestand, en een sessiecookie die 30 dagen geldig is. Het toestemmingsscherm SHALL alleen verschijnen als er nog geen toestemming is gegeven.

#### Scenario: Inloggen starten
- **WHEN** een bezoeker `/oauth2/start` opent
- **THEN** wordt hij doorgestuurd naar `https://id.dutchyland.net/authorize` met de client-id van GrainWork, scope `groups` en `offline_access`, `code_challenge_method=S256` en zonder geforceerde toestemming

### Requirement: Uitrollen in fasen
Pocket ID en de site SHALL elk een eigen schakelaar hebben; de site SHALL NOT aan kunnen zonder Pocket ID, en de module SHALL zonder Pocket ID of site alleen het certificaat toevoegen.

#### Scenario: Site zonder Pocket ID
- **WHEN** `site.enable` aan staat en `pocketId.enable` niet
- **THEN** weigert de evaluatie met een duidelijke melding

### Requirement: Ingetrokken toegang binnen een uur
oauth2-proxy SHALL een sessie die ouder is dan een uur bij het volgende verzoek verversen bij Pocket ID en daarbij de groep opnieuw toetsen. Een uitgezet account of een deelnemer die uit de groep `grainwork` is gehaald, SHALL daarna geen toegang meer hebben.

#### Scenario: Uit de groep gehaald
- **WHEN** de beheerder een deelnemer uit de groep `grainwork` haalt en er meer dan een uur verstrijkt
- **THEN** krijgt die deelnemer bij zijn volgende bezoek geen toegang meer

### Requirement: Uitloggen
`/oauth2/sign_out` SHALL de sessiecookie van de site wissen en, als `rd` naar `id.dutchyland.net` wijst, daarheen doorsturen zodat ook de Pocket ID-sessie eindigt. Doorsturen naar andere domeinen SHALL geweigerd blijven.

#### Scenario: Uitlog-link
- **WHEN** een deelnemer `/oauth2/sign_out?rd=https://id.dutchyland.net/api/oidc/end-session` opent
- **THEN** is de cookie `_grainwork` gewist en komt hij bij het uitlogscherm van Pocket ID
