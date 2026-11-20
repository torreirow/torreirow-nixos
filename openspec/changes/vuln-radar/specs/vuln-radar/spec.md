# Spec Delta

## Purpose

Stelt per gedeclareerd systeem en pakketversie vast welke CVE's daadwerkelijk van toepassing
zijn, en toont alleen die treffers in een geauthenticeerd dashboard.

## ADDED Requirements

### Requirement: Systeeminventaris is per host gedeclareerd

De installatie SHALL per systeem de OS-familie, release en pakketversies vastleggen. Pakketten
SHALL per bron gegroepeerd kunnen worden: distro-pakketten, Nix-pakketten en upstream/custom.
Eigen NixOS-hosts SHALL hun versies uit de NixOS-configuratie betrekken; externe systemen SHALL
via een JSON-bestand aangeleverd kunnen worden.

#### Scenario: NixOS-host uit de configuratie

- **WHEN** een eigen NixOS-host in de configuratie staat
- **THEN** verschijnen de gedeclareerde versies van nginx, PHP en de kernel automatisch in de
  inventaris, zonder handmatige invoer

#### Scenario: Externe host met gemengde bronnen

- **WHEN** een externe host zowel dpkg-, Nix- als upstream-pakketten opgeeft
- **THEN** blijven die bronnen per pakket onderscheiden en gebruikt de matching per bron de
  juiste vergelijkingsmethode

#### Scenario: Ontbrekende release of versie

- **WHEN** een systeem geen release of een pakket geen versie heeft
- **THEN** weigert de configuratie met een duidelijke melding in plaats van het pakket stil over
  te slaan

### Requirement: Alleen versiebewezen CVE's zijn toepasselijk

Het systeem SHALL een CVE alleen als toepasselijk markeren als de geïnstalleerde versie lager is
dan de vastgestelde fixed version voor dezelfde ecosystem en release. Een productnaam alleen is
niet voldoende.

#### Scenario: Geïnstalleerde versie is te oud

- **WHEN** de geïnstalleerde versie lager is dan de fixed version van de betreffende release
- **THEN** verschijnt de CVE als toepasselijk voor dat systeem en pakket

#### Scenario: Geïnstalleerde versie is gefixt

- **WHEN** de geïnstalleerde versie gelijk is aan of hoger is dan de fixed version
- **THEN** verschijnt de CVE niet als toepasselijk

#### Scenario: Geen betrouwbare fixed version

- **WHEN** voor een CVE geen fixed version voor de ecosystem/release beschikbaar is
- **THEN** wordt de CVE als onbekend geteld en niet als toepasselijk getoond

### Requirement: Matching gebruikt de bron die bij het pakket hoort

Distro-pakketten SHALL tegen de bijbehorende distro-tracker worden gematcht, Nix-pakketten tegen
de Nix-vulnerabilitydata en upstream-pakketten tegen vendor- of NVD-data. De KEV-status SHALL
als aparte exploitatie-indicator worden meegenomen.

#### Scenario: Debian-pakket

- **WHEN** een pakket uit dpkg komt op Debian trixie
- **THEN** gebruikt de matching de fixed versions van de Debian Security Tracker voor trixie

#### Scenario: Ubuntu zonder ESM

- **WHEN** een Ubuntu-systeem geen ESM heeft
- **THEN** tellen fixes die alleen via een ESM-pocket beschikbaar zijn niet als opgelost

#### Scenario: Nix- of upstream-pakket

- **WHEN** een pakket uit Nix of een handmatige upstream-versie komt
- **THEN** gebruikt de matching Nix-vulnerabilitydata of de vendor/NVD-versierange

#### Scenario: Bron tijdelijk onbereikbaar

- **WHEN** een vulnerability-bron niet antwoordt
- **THEN** blijft het dashboard werken en wordt het betrokken resultaat als onbekend gemarkeerd

### Requirement: Dashboard toont alleen toepasselijke CVE's

Het dashboard SHALL per systeem en pakket alleen toepasselijke CVE's tonen, met severity, CVE-ID,
fixed version, bron en link. CVE's voor niet-gedeclareerde pakketten SHALL niet verschijnen. Het
aantal onbekende gevallen SHALL apart zichtbaar zijn.

#### Scenario: Upstream-testasset

- **WHEN** de testasset nginx 1.30.7 en PHP 8.3.36 bevat
- **THEN** toont nginx geen recente treffers en PHP de dertien november-CVE's

#### Scenario: Package niet aanwezig

- **WHEN** een systeem geen nginx heeft
- **THEN** verschijnen er geen nginx-CVE's voor dat systeem

#### Scenario: Onbekende telling

- **WHEN** een of meer CVE's niet te beoordelen zijn
- **THEN** toont de pagina een aparte teller voor onbekend, zonder die als toepasselijk te
  presenteren

### Requirement: Dashboard is geauthenticeerd bereikbaar

Het dashboard SHALL bereikbaar zijn op `https://vulns.toorren.net` achter Authelia-forward-auth.
De collector SHALL alleen op `127.0.0.1` luisteren en NIET rechtstreeks via een firewallpoort
bereikbaar zijn.

#### Scenario: Onbevoegd verzoek

- **WHEN** een niet-geauthenticeerde gebruiker het dashboard opvraagt
- **THEN** wordt de gebruiker naar de Authelia-login gestuurd

#### Scenario: Directe poorttoegang

- **WHEN** een client de collectorpoort vanaf een ander adres dan localhost benadert
- **THEN** is er geen verbinding mogelijk

#### Scenario: Geauthenticeerd verzoek

- **WHEN** een geauthenticeerde gebruiker het dashboard opvraagt
- **THEN** ziet die de toepasselijke CVE's per systeem en pakket

### Requirement: Machine-leesbare uitvoer

Het systeem SHALL naast de HTML-weergave een `/vulns.json` aanbieden met dezelfde inventaris,
treffers, onbekende gevallen en laatste verversingstijd.

#### Scenario: JSON opvragen

- **WHEN** een geauthenticeerde client `/vulns.json` opvraagt
- **THEN** ontvangt die geldige JSON met dezelfde gegevens als de HTML-weergave

### Requirement: Veroudering en degradatie zijn zichtbaar

Het systeem SHALL de laatste succesvolle verversing tonen en SHALL bij een mislukte bron de
overige resultaten blijven tonen. Een mislukte verversing SHALL niet als geslaagde meting
worden gepresenteerd.

#### Scenario: Bron faalt bij verversen

- **WHEN** een externe bron bij het verversen een fout geeft
- **THEN** blijven de laatst bekende resultaten zichtbaar met een zichtbare verouderingsmelding

#### Scenario: Nooit succesvol ververst

- **WHEN** er nog geen enkele succesvolle verversing is geweest
- **THEN** toont het dashboard dat de data ontbreekt in plaats van een lege, schone pagina
