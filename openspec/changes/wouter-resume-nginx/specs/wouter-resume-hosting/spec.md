# Spec Delta

## Purpose

Maakt de persoonlijke CV-site van Wouter van der Toorren publiek bereikbaar op
`wouter-resume.toorren.net`, met een permanente redirect vanaf de oude naam
`cv-wouter.toorren.net`, zonder dat de site door zoekmachines of AI-crawlers wordt
opgenomen.

## ADDED Requirements

### Requirement: CV-site is publiek bereikbaar op de canonieke host

`https://wouter-resume.toorren.net/` SHALL de statische build uit
`/var/www/cv-wouter` serveren over HTTPS met een geldig certificaat. Een bestaand
bestand of pad MUST met 200 worden geleverd; een niet-bestaand pad MUST een 404
geven en MUST NOT naar de homepage terugvallen.

#### Scenario: Homepage opvragen
- **WHEN** een bezoeker `https://wouter-resume.toorren.net/` opent
- **THEN** antwoordt de site met 200 en toont de Nederlandse cv-homepage

#### Scenario: Engelse vertaling opvragen
- **WHEN** een bezoeker `https://wouter-resume.toorren.net/en/` opent
- **THEN** antwoordt de site met 200 en toont de Engelse versie

#### Scenario: Bestaand bestand opvragen
- **WHEN** een bezoeker een bestaand pad zoals
  `https://wouter-resume.toorren.net/uploads/cv-wouter-van-der-toorren-nl.pdf` opent
- **THEN** levert de site dat bestand met 200

#### Scenario: Onbestaand pad opvragen
- **WHEN** een bezoeker `https://wouter-resume.toorren.net/bestaat-niet` opent
- **THEN** antwoordt de site met 404 en niet met de homepage

### Requirement: Oude hostnaam verwijst permanent door

`http://` en `https://cv-wouter.toorren.net` SHALL met een permanente redirect
(301) verwijzen naar `https://wouter-resume.toorren.net`, met behoud van het
oorspronkelijke pad en de query-string.

#### Scenario: Oude homepage
- **WHEN** een bezoeker `https://cv-wouter.toorren.net/` opent
- **THEN** antwoordt de site met 301 naar `https://wouter-resume.toorren.net/`

#### Scenario: Oud pad met query
- **WHEN** een bezoeker `https://cv-wouter.toorren.net/en/?bron=linkedin` opent
- **THEN** antwoordt de site met 301 naar
  `https://wouter-resume.toorren.net/en/?bron=linkedin`

### Requirement: CV-site wordt niet geïndexeerd en weert AI-crawlers

De site SHALL op alle antwoorden `X-Robots-Tag: noindex, nofollow` meesturen en
SHALL een `robots.txt` leveren die indexatie door gewone zoekmachines uitsluit.
Verzoeken met de user-agent van een bekende AI-crawler MUST met 403 worden
geweigerd.

#### Scenario: Zoekmachine ziet noindex
- **WHEN** een zoekmachine `https://wouter-resume.toorren.net/` opvraagt
- **THEN** bevat het antwoord de header `X-Robots-Tag: noindex, nofollow`

#### Scenario: robots.txt sluit indexatie uit
- **WHEN** een bezoeker `https://wouter-resume.toorren.net/robots.txt` opvraagt
- **THEN** bevat het bestand een `User-agent: *`-groep met `Disallow: /`

#### Scenario: AI-crawler wordt geweigerd
- **WHEN** een verzoek met user-agent `GPTBot/1.2` binnenkomt op
  `https://wouter-resume.toorren.net/`
- **THEN** antwoordt de site met 403

#### Scenario: Gewone browser wordt niet geweigerd
- **WHEN** een verzoek met een normale browser-user-agent binnenkomt op
  `https://wouter-resume.toorren.net/`
- **THEN** antwoordt de site met 200
