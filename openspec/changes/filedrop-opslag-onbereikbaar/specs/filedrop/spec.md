## ADDED Requirements

### Requirement: Melding als de opslag onbereikbaar is
Als de opslag niet bereikbaar is, SHALL het systeem de inzending weigeren met HTTP 503. De melding
noemt de vaste nachtpauze van 23:00 tot 09:00 en zegt dat de inzender het daarna opnieuw kan
proberen. Of de opslag onbereikbaar is, MUST het systeem afleiden uit het antwoord van de opslag
(een verbindingsfout of HTTP 502, 503 of 504). Het tijdstip mag daarvoor niet gebruikt worden.

#### Scenario: Insturen tijdens de nachtpauze
- **WHEN** iemand iets instuurt en de opslag antwoordt met HTTP 503
- **THEN** krijgt de inzender HTTP 503 met een melding die 23:00 en 09:00 noemt

#### Scenario: Opslag valt weg tijdens het insturen
- **WHEN** de opslag tijdens het versturen van een bestand onbereikbaar wordt
- **THEN** krijgt de inzender dezelfde melding over de onbereikbare opslag

#### Scenario: Overdag onbereikbaar
- **WHEN** de opslag overdag onbereikbaar is
- **THEN** krijgt de inzender dezelfde melding, omdat de klok niet meetelt

### Requirement: Contactadres bij een opslagfout
Elke melding over een mislukte opslag SHALL eindigen met de zin dat de inzender contact kan opnemen
via het contactadres als het opnieuw gebeurt. Dat geldt zowel voor een onbereikbare opslag als
voor een andere opslagfout. Op de pagina MUST daarachter een kleinere link "klik hier" staan, die
een mail aan het contactadres opent.

#### Scenario: Andere opslagfout
- **WHEN** de opslag een onverwachte fout geeft, zoals HTTP 500
- **THEN** noemt de melding dat het opslaan mislukte en het contactadres

#### Scenario: Onbereikbare opslag
- **WHEN** de opslag onbereikbaar is
- **THEN** noemt de melding ook het contactadres

#### Scenario: Maillink in de melding
- **WHEN** de pagina een foutmelding toont waarin het contactadres staat
- **THEN** staat daarachter in kleinere letters "klik hier", als link die een mail aan het contactadres opent
