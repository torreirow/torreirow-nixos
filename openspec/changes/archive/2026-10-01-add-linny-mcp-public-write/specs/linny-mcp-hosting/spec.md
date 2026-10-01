# Spec Delta

## REMOVED Requirements

### Requirement: Agent-writes blijven begrensd tot hun eigen quarantaine

**Reason**: De tunnel-token wordt opgehoogd naar volledige schrijfrechten; de quarantaine-term
begrenst die token niet langer. De begrenzing blijft wel bestaan voor de publieke route zolang de
schrijfschakelaar daar uit staat (zie `linny-mcp-oidc`).

**Migration**: Zie de nieuwe requirement "De tunnel-token draagt volledige schrijfrechten". Wie de
oude begrenzing voor de tunnel wil behouden, zet het `claude-web`-record terug op
`read:*,write:inbox`.

## ADDED Requirements

### Requirement: De tunnel-token draagt volledige schrijfrechten

De tunnel-token (`claude-web`) SHALL de scope `read:*,write:*` dragen, zodat een client via de
ssh-tunnel zowel nieuwe documenten kan maken als bestaande, met de hand geschreven notities kan
wijzigen. De quarantaine-term SHALL nog steeds op nieuw door de agent aangemaakte documenten
komen, maar SHALL NOT een voorwaarde zijn om met deze token te mogen schrijven.

#### Scenario: Nieuw document krijgt nog steeds de quarantaine-term

- **WHEN** de agent via de tunnel `create_doc` aanroept
- **THEN** het document SHALL de term `status: agent-draft` dragen

#### Scenario: Bestaande notitie is wijzigbaar via de tunnel

- **WHEN** de agent via de tunnel een bestaand document zonder quarantaine-term probeert te wijzigen
- **THEN** de server SHALL de wijziging uitvoeren

#### Scenario: Tokenwaarde blijft buiten de nix-store

- **WHEN** de gegenereerde configuratie en de nix-store worden geïnspecteerd
- **THEN** de scope van de tunnel-token SHALL alleen uit het versleutelde tokens-bestand komen
- **AND** geen tokenwaarde SHALL in een wereldleesbaar store-pad staan
