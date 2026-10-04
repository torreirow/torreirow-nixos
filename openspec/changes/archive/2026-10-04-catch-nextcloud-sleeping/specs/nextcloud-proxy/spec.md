## ADDED Requirements

### Requirement: Reverse-proxy faalt snel bij een onbereikbare Nextcloud-upstream

Het systeem SHALL de reverse-proxy voor `nxc.toorren.net` zó configureren dat een onbereikbare
upstream (bobadela1 uit, of de Nextcloud-container nog niet klaar) **snel** tot een fout leidt in
plaats van tot aan de lange upload-timeout te blijven hangen. De TCP-connect-timeout SHALL kort zijn
(enkele seconden), terwijl de transfer-timeouts (`proxy_send_timeout`/`proxy_read_timeout`) lang
SHALL blijven zodat grote uploads niet sneuvelen.

#### Scenario: Host is uit tijdens de nachtelijke shutdown
- **WHEN** een bezoeker `nxc.toorren.net` opent terwijl bobadela1 is uitgeschakeld
- **THEN** geeft de proxy binnen enkele seconden (connect-timeout) een fout in plaats van tot een uur
  op de TCP-handshake te wachten

#### Scenario: Grote uploads blijven werken
- **WHEN** een grote upload naar een bereikbare Nextcloud loopt
- **THEN** begrenzen de transfer-timeouts (lang) de overdracht, niet de korte connect-timeout

### Requirement: Onbereikbare Nextcloud toont een tijdbewuste onderhoudspagina

Het systeem SHALL een onbereikbare Nextcloud-upstream op `nxc.toorren.net` afvangen met een
statische onderhoudspagina in plaats van de kale nginx-foutmelding. De afvang SHALL de upstream-fouten
502/503/504 omzetten naar HTTP **503 Service Unavailable** met een `Retry-After`-header, en SHALL
gescoped zijn op uitsluitend de `nxc.toorren.net`-vhost. De onderhoudspagina SHALL client-side (op de
klok van de bezoeker) onderscheid maken tussen het geplande nachtelijke slaapvenster en een
onverwachte storing.

#### Scenario: Vriendelijke pagina met correcte statuscode
- **WHEN** nginx de Nextcloud-upstream niet kan bereiken (502/504) of een 503 ontvangt
- **THEN** serveert de proxy de statische onderhoudspagina met HTTP 503 en een `Retry-After`-header
- **AND** rendert een browser de pagina, terwijl een sync-client het 503-signaal als "tijdelijk niet
  beschikbaar" opvat en afbackt

#### Scenario: Tijdbewuste tekst
- **WHEN** de onderhoudspagina wordt geopend tussen 23:00 en 09:00 (lokale tijd van de bezoeker)
- **THEN** toont de pagina dat Nextcloud bewust slaapt en rond 09:00 terug is
- **WHEN** de pagina buiten dat venster wordt geopend
- **THEN** toont de pagina dat Nextcloud onverwacht onbereikbaar is

#### Scenario: Afvang raakt andere diensten niet
- **WHEN** een andere vhost (bijvoorbeeld Paperless of Grafana) een 502 geeft
- **THEN** toont die dienst NIET de Nextcloud-onderhoudspagina (de afvang is gescoped op
  `nxc.toorren.net`, en de `@sleeping`-location is `internal`)
