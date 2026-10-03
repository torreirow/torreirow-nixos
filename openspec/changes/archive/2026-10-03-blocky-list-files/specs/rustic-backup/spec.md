## ADDED Requirements

### Requirement: Blocky-overlays worden geback-upt
De rustic-manifest SHALL `/data/external/blocky` als bron bevatten, zodat de mutabel bewerkte
denylist-/allowlist-overlays een restore overleven. (De baseline-lijsten zitten al in git en vallen
buiten de scope van deze backup.)

#### Scenario: Overlay in de backup
- **WHEN** de rustic-backup draait
- **THEN** SHALL `/data/external/blocky` onderdeel zijn van de geback-upte bronnen
