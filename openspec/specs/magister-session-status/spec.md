# magister-session-status Specification

## Purpose
Maakt de leeftijd en de laatste refresh van de Magister-sessie zichtbaar in de footer van de
index-pagina en als Prometheus-metrics, zonder een verloopdatum te suggereren.

## Requirements
### Requirement: Sessieleeftijd afleiden uit het access-token
Het systeem SHALL het tijdstip van de oorspronkelijke login bepalen uit de claim `auth_time` van
het opgeslagen access-token. Het SHALL daarbij geen tokenwaarden loggen of publiceren.

#### Scenario: Geldig access-token met auth_time
- **WHEN** `token.json` een access-token bevat waarvan het payload een numerieke `auth_time` heeft
- **THEN** is het logintijdstip gelijk aan die `auth_time`

#### Scenario: Ontbrekend of onleesbaar access-token
- **WHEN** het access-token ontbreekt, geen geldig JWT is, of geen `auth_time` bevat
- **THEN** is het logintijdstip onbekend en gaat de sync zonder fout door

### Requirement: Laatste geslaagde refresh vastleggen
Het systeem SHALL bij elke geslaagde token-refresh het tijdstip als `last_refresh` vastleggen in
`token.json`, in dezelfde atomaire write als de geroteerde tokens.

#### Scenario: Geslaagde refresh
- **WHEN** een refresh-call slaagt
- **THEN** bevat `token.json` daarna `last_refresh` met het tijdstip van die refresh

#### Scenario: Oud token-bestand zonder last_refresh
- **WHEN** `token.json` geen `last_refresh` bevat
- **THEN** wordt de mtime van `token.json` als laatste refresh gebruikt

### Requirement: Sessiestatus tonen op de overzichtspagina
De overzichtspagina SHALL onder "Laatste update:" tonen: sinds wanneer de sessie ingelogd is
(met de leeftijd in dagen), wanneer de laatste refresh was, en dat het token-verloop onbekend is.
Het SHALL geen verloopdatum suggereren.

#### Scenario: Status bekend
- **WHEN** logintijdstip en laatste refresh bekend zijn
- **THEN** toont de footer "Ingelogd sinds: <datum tijd> (<N> dagen)", "Laatste refresh: <datum tijd>"
  en "Token-verloop: onbekend (Magister geeft dit niet prijs)"

#### Scenario: Status onbekend
- **WHEN** het logintijdstip of de laatste refresh onbekend is
- **THEN** toont de footer voor dat veld "onbekend" en wordt de pagina gewoon gegenereerd

### Requirement: Sessiestatus als Prometheus-metric
De heartbeat SHALL `magister_auth_time_seconds` en `magister_last_refresh_seconds` exporteren als
unix-tijdstempels, naast de bestaande `magister_sync_heartbeat_timestamp`. Er SHALL geen alertregel
op de sessieleeftijd worden toegevoegd.

#### Scenario: Waarden bekend
- **WHEN** de heartbeat geschreven wordt en beide tijdstippen bekend zijn
- **THEN** bevat het heartbeat-bestand beide metrics met HELP- en TYPE-regels

#### Scenario: Waarde onbekend
- **WHEN** een tijdstip onbekend is
- **THEN** wordt die metric weggelaten in plaats van als 0 geëxporteerd, en blijft de bestaande
  heartbeat-metric aanwezig
