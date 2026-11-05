## ADDED Requirements

### Requirement: Mesh tussen malandro, lobos en mpenzi
Het systeem SHALL een Nebula-mesh `toorren` op 10.77.0.0/24 bieden met malandro (10.77.0.1) als
lighthouse en relay op UDP 4242, en lobos (10.77.0.2) en mpenzi (10.77.0.3) als nodes. Alleen
overlay-verkeer MUST via de mesh lopen.

#### Scenario: Bereikbaar via de mesh
- **WHEN** alle drie de hosts draaien met geldige certificaten
- **THEN** kan elke host de andere pingen op hun 10.77.0.x-adres

#### Scenario: Lighthouse thuis en onderweg
- **WHEN** een node verbinding zoekt met de lighthouse
- **THEN** probeert hij 192.168.2.52:4242 en wg.toorren.net:4242

### Requirement: Toegangsbeleid op mpenzi
Op mpenzi MUST de mesh tcp 22 (ssh) en tcp 21118 (RustDesk) alleen toestaan vanaf host lobos.
ICMP SHALL vanaf elke mesh-host toegestaan zijn.

#### Scenario: lobos mag
- **WHEN** lobos verbindt met 10.77.0.3 op poort 22 of 21118
- **THEN** komt de verbinding tot stand

#### Scenario: malandro mag niet
- **WHEN** malandro verbindt met 10.77.0.3 op poort 22 of 21118
- **THEN** wordt de verbinding geweigerd

### Requirement: Bouwbaar zonder certificaten
Een host MUST bouwen zolang zijn Nebula-certificaten nog niet in de repo staan. Nebula SHALL dan
uit staan, en de evaluatie SHALL een warning geven die de ontbrekende bestanden noemt.

#### Scenario: Nog geen certs
- **WHEN** `secrets/nebula-<host>.*.age` ontbreekt
- **THEN** slaagt de build, staat er geen nebula-service en toont de evaluatie een warning

### Requirement: Geen sleutels in de repo of store
De Nebula-CA-sleutel MUST NOT in de repo staan. Host-certificaten en -sleutels MUST via agenix
versleuteld zijn en alleen leesbaar zijn voor de Nebula-service.

#### Scenario: Sleutel op de host
- **WHEN** Nebula actief is
- **THEN** is de host-sleutel een agenix-secret van `nebula-toorren` met modus 0400
