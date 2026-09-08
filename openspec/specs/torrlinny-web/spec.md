# torrlinny-web Specification

## Purpose
Biedt een geauthenticeerde, statische web-view van de torrlinny-notities op `linny.toorren.net`,
waarin notities gelezen kunnen worden en doorzocht/gefilterd op taxonomie en datum, en die
automatisch bijwerkt na een push naar `main` — zonder de content-repo te wijzigen.
## Requirements
### Requirement: Notities worden als statische HTML ontsloten

Het systeem SHALL de markdown-notities uit `torreirow/torrlinny` renderen tot statische HTML en
serveren op `linny.toorren.net` achter Authelia. De content-repo SHALL hierbij niet gewijzigd worden
(overlay-frontend).

#### Scenario: Notitie opvraagbaar
- **WHEN** een gebruiker (na Authelia-login) een notitie-URL opent
- **THEN** wordt de gerenderde markdown-inhoud getoond met titel, datum en taxonomie-chips

#### Scenario: Niet-geauthenticeerd geblokkeerd
- **WHEN** een niet-ingelogde bezoeker `linny.toorren.net` opent
- **THEN** wordt hij naar de Authelia-login doorgestuurd (geen notitie-inhoud zichtbaar)

### Requirement: Filteren op taxonomie en sorteren op datum

Het systeem SHALL de notities laten filteren via facet-filters op de taxonomieën
(customer/project/type/tag/owner/subject/doctype) en laten sorteren op datum.

#### Scenario: Facet-filter
- **WHEN** een gebruiker een taxonomie-waarde (bijv. `customer: technative`) als filter kiest
- **THEN** worden alleen de notities met die waarde getoond

#### Scenario: Sorteren op datum
- **WHEN** de resultaten getoond worden
- **THEN** kunnen ze op creatiedatum (`crdate`) gesorteerd worden

### Requirement: Full-text zoeken

Het systeem SHALL full-text zoeken op termen in de notitie-inhoud ondersteunen (client-side index).

#### Scenario: Zoekterm
- **WHEN** een gebruiker een term intypt die in de tekst van een notitie voorkomt
- **THEN** verschijnt die notitie in de zoekresultaten

### Requirement: Automatische rebuild bij wijzigingen

Het systeem SHALL de site automatisch opnieuw bouwen wanneer er nieuwe commits op `main` staan, en
SHALL geen build doen wanneer er niets gewijzigd is.

#### Scenario: Nieuwe commit
- **WHEN** er naar `main` van torrlinny gepusht is
- **THEN** herbouwt de timer-gestuurde service binnen het poll-interval de site met de nieuwe inhoud

#### Scenario: Geen wijziging
- **WHEN** de service draait maar `HEAD` gelijk is aan `origin/main` en er al een live-build is
- **THEN** wordt de build overgeslagen

### Requirement: Robuuste publicatie (atomic + keep-last-good)

Het systeem SHALL nieuwe builds atomisch live zetten en bij een build-fout de vorige goede versie
blijven serveren.

#### Scenario: Half-gebouwde site nooit zichtbaar
- **WHEN** een nieuwe build loopt
- **THEN** blijft nginx de vorige build serveren tot de nieuwe build volledig klaar is (atomische swap)

#### Scenario: Build-fout breekt de live-site niet
- **WHEN** `hugo` of `pagefind` faalt tijdens een rebuild
- **THEN** blijft de laatst succesvol gebouwde site live (geen swap)

