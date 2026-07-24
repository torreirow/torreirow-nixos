## ADDED Requirements

### Requirement: Token routing naar ontvanger
De service SHALL een `_token` veld in de POST body gebruiken om het bijbehorende formulier op te zoeken in de configuratie en de email te sturen naar het geconfigureerde `to` adres van dat formulier.

#### Scenario: Bekende token routed naar juist adres
- **WHEN** een POST wordt gedaan met `_token=abc123` en de configuratie bevat `"abc123": { "to": "info@wereldvanbegrip.nl", ... }`
- **THEN** wordt de email verstuurd naar `info@wereldvanbegrip.nl`

#### Scenario: Onbekende token wordt geweigerd
- **WHEN** een POST wordt gedaan met een `_token` waarde die niet in de configuratie staat
- **THEN** retourneert de service HTTP 403 met body `{"ok": false, "error": "invalid token"}`

#### Scenario: Ontbrekend token wordt geweigerd
- **WHEN** een POST wordt gedaan zonder `_token` veld
- **THEN** retourneert de service HTTP 400 met body `{"ok": false, "error": "missing token"}`

### Requirement: Token configuratie per formulier
Elke token in de configuratie SHALL de volgende velden bevatten:
- `name`: leesbare naam voor gebruik in email onderwerp
- `to`: ontvanger emailadres
- `allowedOrigins`: lijst van toegestane origins (bijv. `["https://wereldvanbegrip.nl"]`)

#### Scenario: Formulier configuratie volledig
- **WHEN** de service opstart met een token configuratie die `name`, `to` en `allowedOrigins` bevat
- **THEN** accepteert de service verzoeken met dat token en verwerkt ze correct

#### Scenario: Formulier configuratie onvolledig
- **WHEN** de service opstart met een token configuratie waarbij `to` ontbreekt
- **THEN** logt de service een fout en weigert op te starten
