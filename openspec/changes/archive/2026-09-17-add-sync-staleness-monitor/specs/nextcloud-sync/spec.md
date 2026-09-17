## ADDED Requirements

### Requirement: Succesmoment van een sync vastleggen
Het systeem SHALL na elke geslaagde sync het tijdstip daarvan vastleggen in een bestand per
sync-paar, zodat losstaande bewaking kan vaststellen of er recent nog gesynct is zonder de
journal te hoeven doorzoeken.

Het vastleggen SHALL uitsluitend plaatsvinden wanneer de sync daadwerkelijk is geslaagd; een
mislukte sync laat het eerder vastgelegde tijdstip ongemoeid.

#### Scenario: Sync slaagt
- **WHEN** een sync normaal eindigt
- **THEN** is het tijdstip van dat moment vastgelegd voor dat sync-paar

#### Scenario: Sync mislukt
- **WHEN** een sync eindigt met een foutstatus
- **THEN** blijft het eerder vastgelegde tijdstip ongewijzigd

#### Scenario: Meerdere sync-paren
- **WHEN** er meer dan één sync-paar geconfigureerd is
- **THEN** houdt elk paar zijn eigen tijdstip bij, onafhankelijk van de andere

#### Scenario: Locatie leesbaar voor bewaking
- **WHEN** een bewakingsproces het vastgelegde tijdstip wil lezen
- **THEN** is dat beschikbaar op een vast, voorspelbaar pad dat uit de sync-naam volgt
