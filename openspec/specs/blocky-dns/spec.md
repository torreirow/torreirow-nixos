# blocky-dns Specification

## Purpose
TBD - created by archiving change add-blocky-dns-ui. Update Purpose after archive.

## Requirements

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

### Requirement: Eigen domeinlijsten worden uit bestanden geladen
Eigen denylist-groepen SHALL hun domeinen uit platte tekstbestanden (hosts-formaat) laden i.p.v.
inline in de Nix-config. De baseline-bestanden SHALL in de repo staan (`modules/blocky/lists/`) en
in git versiebeheerd zijn.

#### Scenario: Baseline-domein geblokkeerd
- **WHEN** een domein in de baseline-`.txt` van een actieve groep staat en blocky draait
- **THEN** SHALL blocky dat domein blokkeren voor de clients van die groep

#### Scenario: Geen domeinen inline in Nix
- **WHEN** de blocky-module wordt bekeken
- **THEN** SHALL een eigen domeinlijst naar een bestand verwijzen, niet als inline YAML-blok staan

### Requirement: Elke groep heeft een mutabel overlay-bestand naast de baseline
Elke eigen groep SHALL naast de baseline een mutabel overlay-bestand hebben op
`/data/external/blocky/denylists.d/<groep>.txt` (en een allowlist-overlay-bestand op
`/data/external/blocky/allowlists.d/<groep>.txt`). blocky SHALL de bronnen van een groep
samenvoegen. (blocky accepteert als bron alleen een bestand, geen directory of glob.) De
overlay-bestanden SHALL bestaan (leeg aangemaakt via tmpfiles, `root:root 0644`, bewerkbaar met
`sudo`) en door blocky gelezen worden onder `DynamicUser` + `ProtectSystem=strict`.

#### Scenario: Overlay voegt een blokkade toe zonder rebuild
- **WHEN** een beheerder een domein in de denylist-overlay van een groep zet en de lijsten herlaadt
- **THEN** SHALL blocky dat domein blokkeren zonder `nixos-rebuild` of service-herstart

#### Scenario: Allowlist-overlay geeft live vrij
- **WHEN** een beheerder een domein in de allowlist-overlay van een groep zet en herlaadt
- **THEN** SHALL dat domein weer resolveren voor die groep

#### Scenario: Baseline overleeft verlies van de overlay
- **WHEN** het overlay-bestand leeg is of ontbreekt
- **THEN** SHALL de baseline uit git na een rebuild gewoon weer actief zijn en SHALL blocky starten

### Requirement: Lijsten live herlaadbaar via een helper
Er SHALL een `blocky-refresh`-commando zijn dat `POST http://127.0.0.1:4000/api/lists/refresh`
aanroept en de HTTP-status toont (geen stille fout).

#### Scenario: Refresh activeert overlay-wijzigingen
- **WHEN** een beheerder na een overlay-wijziging `blocky-refresh` draait
- **THEN** SHALL blocky alle bronnen opnieuw inlezen en SHALL het commando slagen (of de foutstatus tonen)
