# wallos-service Specification

## Purpose
Wallos op malandro (`subscriptions.toorren.net`) als self-hosted overzicht van abonnementen en terugkerende uitgaven, met login via Authelia-OIDC.

## Requirements

### Requirement: Wallos draait als OCI container
De service SHALL draaien als NixOS OCI container via `virtualisation.oci-containers.containers.wallos` met image `bellamy/wallos:latest`, gebonden op `127.0.0.1:8095:80`.

#### Scenario: Container start automatisch
- **WHEN** malandro opstart
- **THEN** draait de wallos container en is poort 8095 lokaal bereikbaar

#### Scenario: Container gebruikt juiste volumes
- **WHEN** de container actief is
- **THEN** zijn `/data/external/wallos/db` gemount op `/var/www/html/db` en `/data/external/wallos/logos` op `/var/www/html/images/uploads/logos`

### Requirement: Wallos is bereikbaar via subscriptions.toorren.net
De service SHALL bereikbaar zijn via HTTPS op subscriptions.toorren.net met een geldig Let's Encrypt certificaat (useACMEHost = "toorren.net").

#### Scenario: HTTPS toegang
- **WHEN** een gebruiker https://subscriptions.toorren.net opent
- **THEN** wordt de request doorgezet naar de Wallos container op poort 8095

#### Scenario: HTTP redirect
- **WHEN** een gebruiker http://subscriptions.toorren.net opent
- **THEN** wordt hij doorgestuurd naar HTTPS

### Requirement: Wallos gebruikt SQLite in het db-volume
Wallos SHALL zijn gegevens opslaan in de SQLite-database `wallos.db` in het gemounte db-volume
(`/data/external/wallos/db/wallos.db` op de host). Wallos ondersteunt geen andere database; er is
geen MariaDB-database voor Wallos.

#### Scenario: Gegevens staan in wallos.db
- **WHEN** een gebruiker een abonnement toevoegt
- **THEN** staat dat abonnement in `/data/external/wallos/db/wallos.db`

#### Scenario: Geen MariaDB-afhankelijkheid
- **WHEN** MariaDB op malandro niet draait
- **THEN** start Wallos en toont het de bestaande abonnementen

### Requirement: Login uitsluitend via Authelia OIDC
Wallos SHALL geconfigureerd zijn met `OIDC_ENABLED=true` en `OIDC_DISABLE_PASSWORD_LOGIN=true`, zodat gebruikers uitsluitend via Authelia kunnen inloggen.

#### Scenario: Niet-ingelogde gebruiker
- **WHEN** een niet-ingelogde gebruiker subscriptions.toorren.net bezoekt
- **THEN** wordt hij doorgestuurd naar de Authelia login pagina

#### Scenario: Succesvol inloggen via Authelia
- **WHEN** een gebruiker inlogt via Authelia
- **THEN** wordt hij teruggestuurd naar Wallos en heeft hij een actieve sessie

#### Scenario: Eigen login formulier niet beschikbaar
- **WHEN** een gebruiker probeert in te loggen via het Wallos wachtwoord formulier
- **THEN** is die optie niet aanwezig of niet functioneel

### Requirement: Persistent data overleeft container updates
Alle Wallos data SHALL opgeslagen worden buiten de container op `/data/external/wallos/`.

#### Scenario: Container update
- **WHEN** de container image wordt bijgewerkt en opnieuw gestart
- **THEN** zijn alle abonnementen, instellingen en geüploade logo's nog aanwezig

### Requirement: Secrets geladen via agenix
Alle gevoelige configuratie (het OIDC client secret) SHALL geladen worden via `--env-file` vanuit een agenix secret, niet hardcoded in de Nix config.

#### Scenario: Secret aanwezig bij container start
- **WHEN** de container start
- **THEN** is OIDC_CLIENT_SECRET beschikbaar als environment variabele
