## ADDED Requirements

### Requirement: Melden wanneer werk te lang niet geslaagd is
Het systeem SHALL per bewaakt item de tijd sinds het laatste geslaagde moment bepalen en een
melding versturen zodra die te ver oploopt, zodat een storing opvalt zonder dat elke losse
mislukking gemeld hoeft te worden.

#### Scenario: Recent geslaagd
- **WHEN** het laatste succes korter geleden is dan de zachte drempel
- **THEN** wordt er geen melding verstuurd

#### Scenario: Harde drempel overschreden
- **WHEN** het laatste succes langer geleden is dan de harde drempel
- **THEN** wordt er een melding verstuurd die het item noemt en hoe lang het geleden is

#### Scenario: Melding blijft herhalen zolang de situatie duurt
- **WHEN** een item bij twee opeenvolgende controles nog steeds te oud is
- **THEN** wordt bij elke controle opnieuw gemeld, hoogstens één keer per controlemoment

### Requirement: Een readiness-check bepaalt het zachte venster
Het systeem SHALL tussen de zachte en de harde drempel alleen melden wanneer een per item
opgegeven readiness-commando slaagt, zodat er geen alarm afgaat tijdens geplande onbereikbaarheid
van de onderliggende dienst.

#### Scenario: Zacht venster, dienst niet beschikbaar
- **WHEN** het laatste succes tussen de zachte en de harde drempel ligt en het readiness-commando
  faalt
- **THEN** wordt er geen melding verstuurd

#### Scenario: Zacht venster, dienst wel beschikbaar
- **WHEN** het laatste succes tussen de zachte en de harde drempel ligt en het readiness-commando
  slaagt
- **THEN** wordt er een melding verstuurd

#### Scenario: Harde drempel wint van readiness
- **WHEN** het laatste succes de harde drempel heeft overschreden en het readiness-commando faalt
- **THEN** wordt er alsnog een melding verstuurd

#### Scenario: Geen readiness-commando opgegeven
- **WHEN** een item geen readiness-commando heeft
- **THEN** geldt uitsluitend de zachte drempel en gedraagt het item zich als een kale
  ouderdomscontrole

### Requirement: Controle draait periodiek en haalt gemiste momenten in
Het systeem SHALL de controle op een vast moment per dag uitvoeren en een gemist moment inhalen
zodra de machine weer beschikbaar is, zodat een slapende of uitgeschakelde laptop geen controles
overslaat.

#### Scenario: Machine was actief op het geplande moment
- **WHEN** het geplande controlemoment verstrijkt terwijl de gebruikerssessie draait
- **THEN** wordt de controle op dat moment uitgevoerd

#### Scenario: Machine sliep op het geplande moment
- **WHEN** het geplande moment werd gemist doordat de machine in slaapstand stond
- **THEN** wordt de controle uitgevoerd zodra de machine weer actief is

### Requirement: Meerdere items worden onafhankelijk bewaakt
Het systeem SHALL meerdere bewaakte items naast elkaar ondersteunen, elk met een eigen
stempelbestand, drempels, readiness-commando en meldtekst.

#### Scenario: Eén item te oud, ander item recent
- **WHEN** twee items bewaakt worden en alleen het eerste de drempel overschrijdt
- **THEN** wordt uitsluitend over het eerste item gemeld

#### Scenario: Falend readiness-commando blokkeert andere items niet
- **WHEN** het readiness-commando van het ene item faalt
- **THEN** worden de overige items alsnog beoordeeld

### Requirement: De teller begint bij installatie
Het systeem SHALL ervoor zorgen dat het stempelbestand van een bewaakt item bestaat vanaf het
moment dat de bewaking wordt ingeschakeld, zodat een ontbrekend bestand niet tot een onmiddellijke
melding leidt en de betekenis eenduidig blijft: "zo lang geleden is het voor het laatst gelukt,
of anders zo lang geleden is de bewaking ingesteld".

#### Scenario: Bewaking net ingeschakeld
- **WHEN** de bewaking voor een item voor het eerst actief wordt en er nog geen stempelbestand is
- **THEN** wordt dat bestand aangemaakt met het huidige tijdstip en volgt er geen melding

#### Scenario: Stempelbestand ontbreekt bij een controle
- **WHEN** het stempelbestand tijdens een controle niet leesbaar is
- **THEN** faalt de controle niet en wordt dat in de journal vastgelegd

### Requirement: Melden gebeurt via het bestaande meldkanaal
Het systeem SHALL de melding versturen via de bestaande meldingsunit, zodat er één kanaal en één
plek voor het toegangstoken blijft.

#### Scenario: Melding verstuurd
- **WHEN** een item de drempel overschrijdt
- **THEN** wordt de melding via dezelfde meldingsunit verstuurd als de faalmeldingen van andere
  services

#### Scenario: Meldkanaal onbereikbaar
- **WHEN** het versturen van de melding mislukt
- **THEN** eindigt de controle met een foutstatus en staat de reden in de journal
