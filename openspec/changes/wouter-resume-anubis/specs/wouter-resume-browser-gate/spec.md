# Spec Delta

## Purpose

Beschermt de CV-site tegen AI-crawlers, scrapers en niet-browserclients door
iedere bezoeker eerst een browser/proof-of-work-controle te laten doorlopen,
zonder de bestaande Cap-beveiliging van de PDF-downloads te verwijderen.

## ADDED Requirements

### Requirement: Elke request vereist een browsercontrole
De site SHALL alle requests via Anubis laten lopen en SHALL pas content leveren
nadat de bezoeker een proof-of-work-challenge succesvol heeft opgelost en een
geldige ondertekende cookie heeft ontvangen.

#### Scenario: Eerste bezoek met een browser
- **WHEN** een bezoeker zonder Anubis-cookie de homepage opent
- **THEN** krijgt hij de challenge-pagina
- **AND** pas na het oplossen daarvan de gevraagde pagina

#### Scenario: Terugkerend bezoek
- **WHEN** een bezoeker met een geldige Anubis-cookie de site opent
- **THEN** wordt de pagina direct geleverd zonder nieuwe challenge

### Requirement: Niet-browsers krijgen geen content
Clients die geen JavaScript kunnen uitvoeren, waaronder `curl`, scrapers en
AI-crawlers, MUST NOT de HTML, PDF's of andere site-inhoud ontvangen. Zij
krijgen alleen de challenge-pagina of een weigering.

#### Scenario: curl zonder challenge
- **WHEN** een client zonder JavaScript de homepage opvraagt
- **THEN** bevat het antwoord geen CV-inhoud
- **AND** wordt geen PDF uitgeleverd

#### Scenario: AI-crawler met een browser-user-agent
- **WHEN** een crawler een browser-user-agent gebruikt maar geen challenge oplost
- **THEN** krijgt hij de challenge en geen pagina-inhoud

### Requirement: Linkpreviews blijven beperkt mogelijk
Met Open Graph-passthrough SHALL preview-clients de OG-metadata kunnen lezen,
maar MUST NOT de volledige pagina-inhoud of PDF's kunnen ophalen.

#### Scenario: LinkedIn-preview
- **WHEN** LinkedIn de site ophaalt voor een linkpreview
- **THEN** zijn titel, beschrijving en OG-afbeelding beschikbaar
- **AND** blijft de rest van de pagina achter de challenge

### Requirement: PDF-downloads blijven dubbel beschermd
Directe toegang tot `/uploads/*.pdf` SHALL 404 blijven geven. Een PDF SHALL
alleen via `/download` beschikbaar komen na zowel een geldige Anubis-cookie als
een geldig Cap-token.

#### Scenario: PDF zonder Cap-token
- **WHEN** een bezoeker met een geldige Anubis-cookie `/download` zonder Cap-token aanroept
- **THEN** geeft de broker een 403 en geen PDF

#### Scenario: Directe PDF-URL
- **WHEN** een bezoeker `/uploads/cv-wouter-van-der-toorren-nl.pdf` opvraagt
- **THEN** krijgt hij een 404

### Requirement: Interne health checks blijven bereikbaar
Een health check vanaf de lokale host SHALL zonder Anubis-challenge een
succesvol antwoord krijgen, zodat monitoring de beschikbaarheid kan meten.

#### Scenario: Lokale health check
- **WHEN** een monitor op de server de health-endpoint aanroept
- **THEN** krijgt hij een 200 zonder challenge
- **AND** is dezelfde endpoint van buitenaf niet zonder challenge bereikbaar
