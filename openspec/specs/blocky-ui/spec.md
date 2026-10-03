# blocky-ui Specification

## Purpose
TBD - created by archiving change add-blocky-dns-ui. Update Purpose after archive.

## Requirements

### Requirement: blocky-ui draait als OCI container
blocky-ui SHALL draaien als NixOS OCI container via
`virtualisation.oci-containers.containers.blocky-ui` met image `ghcr.io/gabeduartem/blocky-ui`
(vaste versie-tag), gebonden op `127.0.0.1:8087:3000`.

#### Scenario: Container start automatisch
- **WHEN** malandro opstart
- **THEN** draait de blocky-ui container en is poort 8087 lokaal bereikbaar

### Requirement: blocky-ui praat met blocky's API
blocky-ui SHALL blocky's REST-API benaderen via `host.docker.internal:4000`, geconfigureerd in
`blocky-ui.yml` (`BLOCKY_UI_CONFIG`). De container SHALL `--add-host=host.docker.internal:host-gateway`
gebruiken.

#### Scenario: UI toont blocky-status
- **WHEN** een geautoriseerde gebruiker het dashboard opent
- **THEN** toont blocky-ui de status, blocking-schakelaar en lijsten op basis van blocky's API

### Requirement: blocky-ui toont historische query-log uit MariaDB
blocky-ui SHALL de MariaDB-database `blocky` als `logSource` lezen (via `host.docker.internal:3306`)
om de historische query-log te tonen. `blocky-ui.yml` SHALL statisch zijn en de DB-DSN via een
`file:`-referentie laden uit een read-only gemount agenix secret; het wachtwoord SHALL NOT in
`blocky-ui.yml` of de nix-store staan.

#### Scenario: Query-log zichtbaar
- **WHEN** blocky queries heeft gelogd en de gebruiker de log-weergave opent
- **THEN** toont blocky-ui de historische queries uit database `blocky`

### Requirement: blocky-ui overzichtskaarten tonen live statistieken
De blocky-ui overzichtskaarten (totaal queries, geblokkeerd, cache-hitrate, response-tijd) SHALL
gevuld worden uit blocky's `statistics`-API. Blocky SHALL daarvoor `statistics.enable = true`
draaien; omdat die sectie pas vanaf blocky 0.30+ bestaat, SHALL de module blocky 0.35 gebruiken
(package-override uit de `unstable`-input).

#### Scenario: Statistieken beschikbaar
- **WHEN** een geautoriseerde gebruiker het dashboard opent nadat blocky queries heeft verwerkt
- **THEN** tonen de overzichtskaarten statistieken (geen "Statistics unavailable")

### Requirement: blocky-ui bereikbaar via blocky.toorren.net achter Authelia
blocky-ui SHALL uitsluitend bereikbaar zijn via HTTPS op `blocky.toorren.net`
(`useACMEHost = "toorren.net"`, `forceSSL = true`) met nginx forward-auth naar Authelia — de
generieke triple (`/` + `auth_request`, `@authelia_portal`, interne `/authelia`).

#### Scenario: Niet-ingelogde gebruiker
- **WHEN** een niet-ingelogde gebruiker `https://blocky.toorren.net` bezoekt
- **THEN** wordt hij via 302 doorgestuurd naar `auth.toorren.net`

#### Scenario: HTTP redirect
- **WHEN** een gebruiker `http://blocky.toorren.net` opent
- **THEN** wordt hij doorgestuurd naar HTTPS

#### Scenario: Geautoriseerde toegang
- **WHEN** een lid van `group:operations` met 2FA is ingelogd
- **THEN** wordt de request doorgezet naar de blocky-ui container op poort 8087
