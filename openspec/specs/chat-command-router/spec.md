# chat-command-router Specification

## Purpose
Neemt gebruikerscommando's aan uit chatkanalen (Telegram en Signal) en beeldt ze via één gedeelde
router af op dezelfde Home Assistant-acties, met antwoord op het kanaal van herkomst en autorisatie
van de afzender.

## Requirements

### Requirement: Eén gedeelde commando-router

Alle ondersteunde commando's SHALL door één gedeelde router worden afgehandeld die het commando,
de argumenten en een antwoord-doel (notify-service) als invoer neemt, de bijbehorende actie
uitvoert en het resultaat terugmeldt via dat antwoord-doel. De commandodefinities SHALL niet per
kanaal gedupliceerd worden.

#### Scenario: Zelfde commando, kanaal bepaalt het antwoord

- **WHEN** een ondersteund commando binnenkomt met een antwoord-doel
- **THEN** voert de router de actie één keer uit (ongeacht het kanaal)
- **AND** stuurt het antwoord naar het meegegeven antwoord-doel

#### Scenario: Onbekend commando

- **WHEN** een commando binnenkomt dat de router niet kent
- **THEN** meldt de router dat terug via het antwoord-doel in plaats van stil te falen

### Requirement: Commando-pariteit tussen Telegram en Signal

Elk commando dat via Telegram beschikbaar is SHALL ook via Signal beschikbaar zijn, met gelijke
werking en argumentafhandeling. Het toevoegen of wijzigen van een commando SHALL op één plek
gebeuren en daarmee voor beide kanalen gelden.

#### Scenario: Pariteit

- **WHEN** een commando via Telegram werkt
- **THEN** werkt hetzelfde commando via Signal met dezelfde actie en hetzelfde soort antwoord

### Requirement: Telegram-inname via integratie-event

Telegram-commando's SHALL worden aangenomen via het `telegram_command`-event van de
HA-Telegram-integratie en doorgegeven aan de router met het Telegram-antwoord-doel.

#### Scenario: Telegram-commando

- **WHEN** de gebruiker een `/commando` naar de Telegram-bot stuurt
- **THEN** triggert het `telegram_command`-event de router met commando, argumenten en het
  Telegram-antwoord-doel

### Requirement: Signal-inname via polling van de REST-API

Omdat de Signal-integratie geen inkomend event levert, SHALL inkomende Signal-berichten worden
aangenomen door periodiek de signal-cli-REST-receive-endpoint te pollen. Het antwoord gaat terug via
de bestaande Signal-notify-service.

#### Scenario: Signal-commando binnen een pollcyclus

- **WHEN** de gebruiker een `/commando` naar het Signal-bot-nummer stuurt
- **THEN** haalt de eerstvolgende pollcyclus dat bericht op
- **AND** roept de router aan met commando, argumenten en het Signal-antwoord-doel

#### Scenario: Rauwe tekst zelf splitsen

- **WHEN** een Signal-bericht de rauwe tekst `"/aircraft 30"` bevat
- **THEN** splitst de inname die in commando `/aircraft` en argument(en) `[30]` voordat de router
  wordt aangeroepen

### Requirement: Afzender-autorisatie en ruisfilter

Alleen berichten van een gewhiteliste afzender SHALL een commando mogen uitvoeren. Envelopes zonder
daadwerkelijke berichttekst (zoals typ- en leesbevestigingen) SHALL genegeerd worden, evenals tekst
die geen commando is.

#### Scenario: Niet-gewhiteliste afzender

- **WHEN** een `/commando` binnenkomt van een afzender die niet op de whitelist staat
- **THEN** wordt het genegeerd en geen actie uitgevoerd

#### Scenario: Ruis-envelope

- **WHEN** een ontvangen envelope geen berichttekst bevat (typ-indicator of leesbevestiging)
- **THEN** wordt die overgeslagen zonder fout
