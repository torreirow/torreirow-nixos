## ADDED Requirements

### Requirement: Het meldkanaal is herbruikbaar voor niet-faal-meldingen
Het systeem SHALL een aanroepbare verzender beschikbaar stellen die een meegegeven bericht via het
meldkanaal verstuurt, zodat andere componenten een melding kunnen sturen die geen unit-fout is
zonder het toegangstoken opnieuw te lezen of de verzendlogica te dupliceren.

#### Scenario: Eigen bericht versturen
- **WHEN** een component de verzender aanroept met een bericht
- **THEN** wordt dat bericht ongewijzigd via het meldkanaal verstuurd, zonder toevoegingen over
  units of foutstatussen

#### Scenario: Faalmelding blijft ongewijzigd
- **WHEN** een unit faalt en de meldingsunit wordt gestart
- **THEN** bevat het bericht nog steeds de unitnaam en de laatste journalregels van die unit

#### Scenario: Eén tokenlocatie
- **WHEN** zowel de faalmelding als een eigen bericht wordt verstuurd
- **THEN** wordt het toegangstoken in beide gevallen op dezelfde plek gelezen

#### Scenario: Verzenden mislukt
- **WHEN** het meldkanaal het bericht weigert of het token onleesbaar is
- **THEN** eindigt de verzender met een foutstatus en staat de reden in de journal
