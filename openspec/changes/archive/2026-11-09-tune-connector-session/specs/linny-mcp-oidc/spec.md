## ADDED Requirements

### Requirement: Een gekoppelde client blijft gekoppeld bij regelmatig gebruik

De koppeling SHALL blijven bestaan zolang de client hem met enige regelmaat gebruikt; opnieuw
autoriseren SHALL alleen nodig zijn na een langdurige periode van niet-gebruik.

De autorisatieserver geeft bij elke verversing een nieuwe refresh-token uit en verbruikt de oude.
De geconfigureerde levensduur is daardoor geen maximale sessieduur maar een maximale
**stilteperiode**.

#### Scenario: Dagelijks gebruik vereist geen nieuwe autorisatie

- **WHEN** een gekoppelde client de server elke dag ten minste één keer aanspreekt
- **THEN** het aantal volledige autorisatierondes SHALL NOT toenemen
- **AND** de gebruiker SHALL NOT om toestemming of inloggegevens worden gevraagd

#### Scenario: Een nacht of weekend overbrugt de koppeling

- **WHEN** een client de server een etmaal niet aanspreekt en daarna weer wel
- **THEN** de koppeling SHALL nog werken zonder tussenkomst van de gebruiker

### Requirement: De toegangstoken blijft kortlevend

De levensduur van de access-token SHALL NOT worden verlengd om de koppeling te behouden.

Dat is de enige credential die bij elk verzoek over de lijn gaat; het verlengen ervan vergroot het
venster waarin een onderschepte token bruikbaar is. Het behoud van de koppeling hoort te komen van
de refresh-token, die alleen tussen client en autorisatieserver reist.

#### Scenario: Toegangstoken blijft op de standaardlevensduur

- **WHEN** de lifespan-configuratie van de connector-client wordt bekeken
- **THEN** de access-token SHALL een levensduur van ten hoogste één uur hebben

### Requirement: Onthouden toestemming vervalt bij gewijzigde rechten

De autorisatieserver MAY de toestemming van de gebruiker onthouden, en SHALL die opnieuw vragen
zodra het subject, de client, de gevraagde scopes of de audience afwijken van wat eerder is
toegestaan.

Herhaald identiek om toestemming vragen maakt het geheel niet veiliger: het leidt ertoe dat de
gebruiker stopt met lezen wat hij goedkeurt. Juist een wijziging in de gevraagde rechten hoort op
te vallen, en dat lukt alleen als het scherm zeldzaam is.

#### Scenario: Ongewijzigde rechten vragen niet opnieuw om toestemming

- **WHEN** een client binnen de onthoudperiode opnieuw autoriseert met dezelfde scopes en audience
- **THEN** de gebruiker SHALL NOT opnieuw een toestemmingsscherm krijgen

#### Scenario: Gewijzigde scopes vragen wel opnieuw om toestemming

- **WHEN** een client andere scopes of een andere audience vraagt dan eerder toegestaan
- **THEN** de gebruiker SHALL opnieuw expliciet om toestemming worden gevraagd

### Requirement: De wijziging raakt alleen de connector-client

De instellingen voor levensduur en toestemming SHALL uitsluitend gelden voor de connector-client.

#### Scenario: Andere clients behouden hun eigen instellingen

- **WHEN** een andere OpenID Connect-client op dezelfde autorisatieserver autoriseert
- **THEN** die SHALL de globale levensduren gebruiken en SHALL NOT het profiel van de connector erven

#### Scenario: De browsersessie blijft ongemoeid

- **WHEN** de configuratie van de sessie-cookie wordt bekeken
- **THEN** de inactiviteits- en verlooptijden SHALL ongewijzigd zijn; die beschermen een openstaande
  browser en staan los van de koppeling
