## Purpose

Biedt een geauthenticeerd overzichtsdashboard dat de gedeclareerde applicaties op de host (Docker-containers, nginx-vhosts en curated native services) afzet tegen hun live runtime-status, zodat drift (kapotte of niet-gedeclareerde services) in één oogopslag zichtbaar is.

## ADDED Requirements

### Requirement: Gedeclareerde applicaties worden geïnventariseerd

Het systeem SHALL bij `nixos-rebuild` een inventaris van gedeclareerde applicaties vastleggen, afgeleid uit de NixOS-configuratie: alle OCI/Docker-containers, alle nginx virtualHosts, en een expliciet gecureerde lijst van native services. Deze inventaris SHALL beschikbaar zijn voor het dashboard op runtime.

#### Scenario: Container toegevoegd aan config

- **WHEN** een nieuwe OCI-container aan de NixOS-config wordt toegevoegd en het systeem opnieuw wordt gebouwd
- **THEN** verschijnt die container in de gedeclareerde inventaris met zijn naam en image

#### Scenario: nginx-vhost in inventaris

- **WHEN** een nginx virtualHost `<naam>.toorren.net` is gedeclareerd
- **THEN** verschijnt die host in de gedeclareerde inventaris

#### Scenario: Native service op curated lijst

- **WHEN** een service (bijv. `paperless`, `vaultwarden`) op de gecureerde lijst staat
- **THEN** verschijnt die service in de gedeclareerde inventaris

### Requirement: Live runtime-status wordt per request verzameld

Het systeem SHALL bij elk paginaverzoek de actuele runtime-status verzamelen: draaiende en gestopte Docker-containers, de actief/inactief-status van de gecureerde native services, en de daadwerkelijk luisterende TCP-poorten. De status SHALL de werkelijke toestand op het moment van het verzoek weergeven, niet een gecachte momentopname.

#### Scenario: Container is gestopt

- **WHEN** een geconfigureerde container niet draait op het moment van het verzoek
- **THEN** toont het dashboard die container als niet-draaiend

#### Scenario: Verzoek reflecteert actuele toestand

- **WHEN** een container tussen twee verzoeken wordt gestopt
- **THEN** toont het tweede verzoek de container als niet-draaiend zonder dat een aparte verversing nodig is

### Requirement: Soll wordt afgezet tegen ist met een gezondheidsoordeel

Het systeem SHALL per applicatie de gedeclareerde toestand (soll) vergelijken met de runtime-toestand (ist) en een oordeel toekennen: **gezond** (gedeclareerd én draaiend), **kapot** (gedeclareerd maar niet draaiend), of **orphan** (draaiend maar niet gedeclareerd).

#### Scenario: Gezonde applicatie

- **WHEN** een applicatie zowel gedeclareerd is als draait
- **THEN** krijgt die applicatie het oordeel "gezond"

#### Scenario: Kapotte applicatie

- **WHEN** een applicatie gedeclareerd is maar niet draait
- **THEN** krijgt die applicatie het oordeel "kapot"

#### Scenario: Orphan-applicatie

- **WHEN** een container of service draait die niet in de gedeclareerde inventaris voorkomt
- **THEN** krijgt die het oordeel "orphan"

### Requirement: Dashboard is bereikbaar via geauthenticeerde HTTPS-endpoint

Het systeem SHALL het dashboard aanbieden op `https://status.toorren.net`, uitsluitend na succesvolle Authelia forward-authenticatie. Het collector-proces SHALL alleen op `127.0.0.1` luisteren en NIET direct via een firewall-poort bereikbaar zijn.

#### Scenario: Onbevoegd verzoek

- **WHEN** een niet-geauthenticeerde gebruiker `https://status.toorren.net` opvraagt
- **THEN** wordt de gebruiker doorgestuurd naar de Authelia-login

#### Scenario: Geauthenticeerd verzoek

- **WHEN** een via Authelia geauthenticeerde gebruiker het dashboard opvraagt
- **THEN** toont het systeem het overzicht van applicaties met hun gezondheidsoordeel

#### Scenario: Geen directe poorttoegang

- **WHEN** een client de collector-poort rechtstreeks (buiten nginx om) probeert te benaderen vanaf een ander adres dan localhost
- **THEN** is er geen verbinding mogelijk

### Requirement: Machine-leesbare uitvoer

Het systeem SHALL naast de HTML-weergave een machine-leesbare `/status.json` aanbieden met dezelfde inventaris, runtime-status en gezondheidsoordelen.

#### Scenario: JSON opvragen

- **WHEN** een geauthenticeerde client `https://status.toorren.net/status.json` opvraagt
- **THEN** ontvangt de client geldige JSON met per applicatie de gedeclareerde staat, runtime-staat en het oordeel

### Requirement: Robuustheid bij ontbrekende databronnen

Het systeem SHALL een bruikbare pagina blijven tonen wanneer een databron (Docker-socket, systemd, of poortinformatie) tijdelijk niet beschikbaar is, in plaats van te falen met een foutpagina.

#### Scenario: Docker-daemon onbereikbaar

- **WHEN** de Docker-daemon niet reageert op het moment van het verzoek
- **THEN** toont het dashboard de overige informatie en markeert de Docker-sectie als onbeschikbaar in plaats van een serverfout te geven
