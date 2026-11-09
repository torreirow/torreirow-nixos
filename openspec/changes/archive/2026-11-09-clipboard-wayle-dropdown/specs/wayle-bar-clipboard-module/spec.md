## ADDED Requirements

### Requirement: Clipboard icoon in de bar
Het systeem SHALL een clipboard icoon tonen in de wayle-bar rechts naast het planify icoon.

#### Scenario: Icoon zichtbaar in bar
- **WHEN** wayle-bar geladen is
- **THEN** is het clipboard icoon (`edit-copy-symbolic`) zichtbaar in de rechterkant van de bar

#### Scenario: Klik opent dropdown
- **WHEN** de gebruiker op het clipboard icoon klikt
- **THEN** opent de clipboard history dropdown

### Requirement: Bar layout bevat custom-clipboard module
Het systeem SHALL `"custom-clipboard"` opnemen in de bar layout naast `"custom-planify"`.

#### Scenario: Module aanwezig in layout
- **WHEN** wayle-bar opstart
- **THEN** is de `custom-clipboard` module aanwezig in het rechter gedeelte van de bar
