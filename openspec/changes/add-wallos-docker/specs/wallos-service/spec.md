## ADDED Requirements

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

### Requirement: Wallos gebruikt MariaDB als database
De container SHALL verbinding maken met de host MariaDB via `host.docker.internal:3306` met credentials uit de agenix env-file.

#### Scenario: Database verbinding bij opstarten
- **WHEN** de container opstart
- **THEN** verbindt Wallos met de MariaDB `wallos` database via `DB_DRIVER=mysql`

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
Alle gevoelige configuratie (database credentials, OIDC client secret) SHALL geladen worden via `--env-file` vanuit een agenix secret, niet hardcoded in de Nix config.

#### Scenario: Secret aanwezig bij container start
- **WHEN** de container start
- **THEN** zijn DB_DRIVER, DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, OIDC_CLIENT_SECRET en TZ beschikbaar als environment variabelen
