## MODIFIED Requirements

### Requirement: Maximale grootte per inzending
Het systeem SHALL een inzending groter dan 25 MB weigeren met een melding die het contactadres
eghmedia@evangelischegemeente.org noemt. Het formulier MUST deze grens en het
contactadres ook vooraf tonen.

#### Scenario: Te groot
- **WHEN** de bestanden samen groter zijn dan 25 MB
- **THEN** weigert het systeem de inzending met een melding die het contactadres noemt

#### Scenario: Grens zichtbaar
- **WHEN** iemand de pagina opent
- **THEN** staat bij het bestandsveld "Maximaal 25 MB" met een mailto-link naar het contactadres

## ADDED Requirements

### Requirement: Huisstijl-middelen komen van de eigen dienst
De pagina SHALL haar lettertypes, achtergrond en logo alleen van de eigen dienst laden. Ze MUST
geen verzoek doen naar een font-dienst, CDN of de kerk-website. De enige externe bron blijft de
robotcontrole.

#### Scenario: Geen externe huisstijlbronnen
- **WHEN** iemand de pagina opent
- **THEN** komen alle lettertype-, afbeelding- en stijlverzoeken van eghupload.toorren.net

### Requirement: Hero toont de EGH-achtergrond
De kop van de pagina, met logo, kerknaam en titel, SHALL de EGH-achtergrond "Dusk To Dawn 1b"
tonen. Het formulier daaronder MUST een witte achtergrond houden. Als de afbeelding niet laadt,
MUST de kop het kleurverloop in dezelfde tinten tonen.

#### Scenario: Achtergrond geladen
- **WHEN** iemand de pagina opent
- **THEN** staat de afbeelding achter de kop en is het formulier wit

#### Scenario: Afbeelding laadt niet
- **WHEN** de afbeelding niet geladen kan worden
- **THEN** toont de kop het kleurverloop en blijven logo en titel leesbaar

### Requirement: Script-lettertype voor de titel
De grote titel in de kop SHALL in Blenda Script staan. Dit lettertype MUST altijd door de dienst
geleverd worden, zonder handmatige stap op de server.

#### Scenario: Titel in script
- **WHEN** iemand de pagina opent
- **THEN** staat de grote titel in Blenda Script

### Requirement: Gelicentieerd lettertype is optioneel
Alle tekst behalve de titel SHALL in Letter Gothic Std staan als het fontbestand op de server
aanwezig is, zoals in de EGH-presentaties. Ontbreekt het, dan MUST de pagina dezelfde tekst in
Roboto tonen en volledig werken. Het fontbestand MUST NOT in de publieke repository
staan.

#### Scenario: Fontbestand aanwezig
- **WHEN** het Letter Gothic-bestand op de server staat en iemand de pagina opent
- **THEN** staan kerknaam, koppen, uitleg, labels, velden en meldingen in Letter Gothic Std

#### Scenario: Fontbestand ontbreekt
- **WHEN** het Letter Gothic-bestand niet op de server staat
- **THEN** antwoordt de dienst op het fontverzoek met "niet gevonden", toont de pagina die teksten in Roboto en kan iemand gewoon insturen

### Requirement: Terugvallettertype komt van de dienst
Het terugvallettertype Roboto SHALL door de dienst zelf geleverd worden, zodat de pagina ook op
apparaten zonder Roboto (iPhone, Mac, Windows) niet in het standaardlettertype van de browser
staat. Het script-lettertype MUST NOT voor andere tekst dan de titel gebruikt worden.

#### Scenario: Apparaat zonder Roboto en zonder Letter Gothic op de server
- **WHEN** het Letter Gothic-bestand ontbreekt en het apparaat heeft geen Roboto
- **THEN** staat de tekst in Roboto, geleverd door eghupload.toorren.net
