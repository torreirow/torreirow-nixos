# Spec Delta

## Purpose

Een lokaal gehoste Cap-instance op malandro die de captcha levert voor de publieke formulieren
(contactmailer en File Drop), zonder externe captcha-dienst en zonder dat een storing of upgrade
die formulieren stil laat falen.

## ADDED Requirements

### Requirement: Cap is lokaal gehost en alleen via nginx bereikbaar

De captcha-dienst SHALL volledig op malandro draaien en publiek alleen bereikbaar zijn via
`https://cap.toorren.net` (TLS en reverse proxy door nginx). De container-poort MUST uitsluitend
op loopback luisteren; vanaf het LAN of internet is er geen directe toegang.

#### Scenario: Widget laadt via de publieke hostnaam

- **WHEN** een browser op een publieke site de Cap-widget laadt
- **THEN** komen widget en challenge-endpoints van `https://cap.toorren.net` en werkt de captcha

#### Scenario: Container-poort niet vanaf het LAN bereikbaar

- **WHEN** vanaf een ander adres in het LAN rechtstreeks de container-poort wordt benaderd
- **THEN** is er geen verbinding mogelijk

### Requirement: Elke consumer heeft een eigen site-key met secret buiten de Nix store

De mailer en File Drop SHALL elk een eigen site-key gebruiken, en het bijbehorende secret MUST
alleen via agenix op de host staan (niet in de Nix store, niet in de repo). Server-side validatie
gebeurt via `POST /<site-key>/siteverify` met `{"secret": …, "response": …}`.

#### Scenario: Mailer valideert een token

- **WHEN** de mailer een `cap-token` aanbiedt met het secret van key `eaa5abea30`
- **THEN** antwoordt Cap met `success: true` en verstuurt de mailer de mail

#### Scenario: File Drop valideert een token

- **WHEN** filedrop een token aanbiet met het secret van key `92c7e198d7`
- **THEN** antwoordt Cap met `success: true` en slaat filedrop de inzending op

#### Scenario: Secret staat niet in de Nix store

- **WHEN** de gebouwde configuratie en de repo worden doorzocht op het site-secret
- **THEN** komt het alleen voor in het agenix-pad op de host (`/run/secrets/…`)

### Requirement: Site-keys en instellingen overleven een herstart

Site-keys, secrets, instellingen en sessies SHALL persistent opgeslagen worden, zodat een herstart
of container-herstart ze niet verliest. Een bestaande site-key MUST na een herstart zonder
opnieuw instellen blijven werken.

#### Scenario: Herstart zonder keys te verliezen

- **WHEN** de Cap-container opnieuw start
- **THEN** werken de bestaande site-keys direct weer en is er geen nieuwe bootstrap nodig

### Requirement: Analytics-events overleven het vervangen van de container

De event store SHALL op een persistent pad buiten de container staan, zodat events een
container-herstart of image-upgrade overleven en het dashboard de historie blijft tonen.

#### Scenario: Container opnieuw aangemaakt

- **WHEN** de Cap-container met een nieuwe image wordt aangemaakt
- **THEN** zijn de eerder vastgelegde events nog zichtbaar in het dashboard

### Requirement: De dienst draait op een CPU zonder AVX2

Cap SHALL starten en challenges serveren op malandro's Celeron J3455, die geen AVX2 heeft. Als
analytics op zo'n CPU niet beschikbaar is, MUST de captcha zelf blijven werken.

#### Scenario: Start op een niet-AVX2-CPU

- **WHEN** de container op malandro start
- **THEN** antwoordt de dienst met HTTP 200 en werkt het challenge-endpoint, zonder
  `Illegal instruction` in de container-log

### Requirement: Een major upgrade breekt siteverify niet stil

Na een major upgrade SHALL `/siteverify` voor beide site-keys weer `success: true` geven voordat de
upgrade als afgerond geldt. Zolang een secret niet geroteerd is, MUST dat als fout worden
onderkend in de acceptatiecheck en niet pas in productie. Er MUST een gedocumenteerd terugrolpad
zijn (Valkey-snapshot + vorige image).

#### Scenario: Acceptatiecheck na de upgrade

- **WHEN** de upgrade is uitgerold en beide secrets zijn geroteerd en herdeployed
- **THEN** geeft `/siteverify` voor beide keys `success: true` en werken beide formulieren

#### Scenario: Secret nog niet geroteerd

- **WHEN** `/siteverify` voor een key 403 teruggeeft
- **THEN** wordt de upgrade niet als afgerond beschouwd en wordt teruggerold volgens het
  gedocumenteerde pad
