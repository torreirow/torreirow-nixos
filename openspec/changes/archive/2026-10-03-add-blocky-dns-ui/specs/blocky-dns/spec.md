## ADDED Requirements

### Requirement: Blocky draait als native NixOS DNS-service
Blocky SHALL draaien via `services.blocky.enable = true` als native systemd-service op malandro,
met upstreams Cloudflare (1.1.1.1, 1.0.0.1) en Google (8.8.8.8, 8.8.4.4).

#### Scenario: Service start automatisch
- **WHEN** malandro opstart
- **THEN** draait de blocky-service en beantwoordt DNS-queries op `127.0.0.1:53`

#### Scenario: DNS-resolutie werkt
- **WHEN** `dig @127.0.0.1 example.com` wordt uitgevoerd op de host
- **THEN** geeft blocky een geldig antwoord via een upstream

### Requirement: DNS is local-only
Blocky SHALL luisteren op `127.0.0.1:53` zonder firewall-opening voor poort 53, zodat het netwerk
zijn huidige DNS behoudt tot een expliciete latere cutover.

#### Scenario: LAN bereikt blocky-DNS niet
- **WHEN** een host op `192.168.2.0/24` `dig @<malandro-ip> example.com` probeert
- **THEN** komt er geen antwoord van blocky (poort 53 niet open op het LAN)

### Requirement: Ad-blocking via denylists
Blocky SHALL bekende advertentie-/tracking-domeinen blokkeren via de denylists StevenBlack,
AdGuard DNS en KADhosts (dezelfde bronnen als de voormalige Pi-hole-configuratie).

#### Scenario: Geblokkeerd domein
- **WHEN** een domein uit een denylist wordt opgevraagd via `127.0.0.1:53`
- **THEN** antwoordt blocky met een blok-respons (0.0.0.0 / NXDOMAIN), niet het echte adres

### Requirement: REST-API intern bereikbaar, niet publiek
Blocky SHALL zijn HTTP REST-API aanbieden op `0.0.0.0:4000` zonder firewall-opening, zodat alleen
de host en Docker-containers het bereiken. De API SHALL NOT via nginx of publiek ontsloten worden,
en Prometheus-metrics SHALL NOT publiek beschikbaar zijn.

#### Scenario: API vanaf host
- **WHEN** `curl http://127.0.0.1:4000/...` wordt uitgevoerd op malandro
- **THEN** antwoordt blocky's API

#### Scenario: API vanaf Docker-container
- **WHEN** de blocky-ui-container `http://host.docker.internal:4000` benadert
- **THEN** bereikt het blocky's API

#### Scenario: API niet vanaf LAN
- **WHEN** een host op het LAN poort 4000 op malandro benadert
- **THEN** is de poort dicht (firewall default-deny)

### Requirement: Query-log naar MariaDB
Blocky SHALL zijn query-log schrijven naar de MariaDB-database `blocky` via
`settings.queryLog` (type mysql), met credentials uit een agenix secret (niet hardcoded).

#### Scenario: Queries worden gelogd
- **WHEN** blocky DNS-queries verwerkt
- **THEN** verschijnen bijbehorende rijen in de MariaDB-database `blocky`

#### Scenario: Wachtwoord niet in de nix-store
- **WHEN** de gegenereerde blocky-config wordt geïnspecteerd in de nix-store
- **THEN** staat het MariaDB-wachtwoord daar niet in plain tekst (getemplate uit het secret)
