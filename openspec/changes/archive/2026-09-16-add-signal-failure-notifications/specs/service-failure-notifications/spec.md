## ADDED Requirements

### Requirement: Melding bij het falen van een user-service
Het systeem SHALL een Signal-bericht versturen zodra een systemd user-service faalt waaraan de
meldingsunit is gekoppeld, zodat een storing niet dagenlang onopgemerkt blijft.

#### Scenario: Unit faalt
- **WHEN** een user-service met `OnFailure = [ "notify-signal@%N.service" ]` eindigt met een
  foutstatus
- **THEN** wordt er een Signal-bericht verstuurd dat de naam van de falende unit noemt

#### Scenario: Unit slaagt
- **WHEN** diezelfde service normaal eindigt
- **THEN** wordt er geen bericht verstuurd

#### Scenario: Eén template voor meerdere services
- **WHEN** twee verschillende services allebei de meldingsunit aanhaken
- **THEN** noemt elk bericht de eigen unitnaam, zonder dat er per service een aparte unit nodig is

### Requirement: Het bericht bevat genoeg context om de oorzaak te zien
Het systeem SHALL de laatste journalregels van de falende unit meesturen, zodat de ontvanger niet
hoeft in te loggen om vast te stellen wat er misging.

#### Scenario: Unit met loguitvoer
- **WHEN** de falende unit foutregels naar de journal heeft geschreven
- **THEN** staan die regels in het Signal-bericht

#### Scenario: Unit zonder loguitvoer
- **WHEN** de falende unit niets heeft gelogd
- **THEN** wordt er alsnog een bericht verstuurd met de unitnaam en een verwijzing naar het
  journal-commando

### Requirement: Een mislukte melding faalt zichtbaar
Het systeem SHALL de meldingsunit laten falen wanneer de meldingsdienst het bericht weigert, zodat
een kapot meldkanaal zich niet voordoet als een werkend meldkanaal.

#### Scenario: Meldingsdienst weigert
- **WHEN** de API een andere status dan 2xx teruggeeft (verkeerde dienstnaam, ongeldig token)
- **THEN** eindigt de meldingsunit met een foutstatus en staat de respons in de journal

#### Scenario: Token ontbreekt
- **WHEN** het tokenbestand niet bestaat of onleesbaar is
- **THEN** eindigt de meldingsunit met een foutstatus en een expliciete melding daarover

### Requirement: Geen geheimen in de nix-store
Het systeem SHALL het toegangstoken uit een bestand buiten de nix-store lezen.

#### Scenario: Configuratie gebouwd
- **WHEN** de configuratie is gebouwd
- **THEN** bevat geen enkel bestand in de nix-store het token
