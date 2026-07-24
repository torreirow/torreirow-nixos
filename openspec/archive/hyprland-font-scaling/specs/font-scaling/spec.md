## ADDED Requirements

### Requirement: X11 apps hebben gelijke tekstgrootte als Wayland apps
Het systeem SHALL `Xft.dpi` instellen op 120 (96 × monitor scale 1.25) zodat XWayland apps fonts op de juiste grootte renderen zonder compositor-upscale.

#### Scenario: X11 app toont correcte tekstgrootte
- **WHEN** een XWayland app start terwijl `xwayland.force_zero_scaling = true`
- **THEN** worden fonts gerenderd op basis van Xft.dpi 120, vergelijkbaar met Wayland apps op dezelfde monitor

### Requirement: Gebruiker kan tekstgrootte stapsgewijs verhogen
Het systeem SHALL via `Super+Ctrl+Shift+=` de `text-scaling-factor` met 0.1 verhogen, tot een maximum van 2.0.

#### Scenario: Verhogen vanuit standaardwaarde
- **WHEN** gebruiker `Super+Ctrl+Shift+=` indrukt met huidige factor 1.0
- **THEN** wordt de factor 1.1 en verschijnt een notificatie "Tekstgrootte: 1.1×"

#### Scenario: Verhogen op maximum
- **WHEN** gebruiker `Super+Ctrl+Shift+=` indrukt met huidige factor 2.0
- **THEN** blijft de factor 2.0 (geen overflow)

### Requirement: Gebruiker kan tekstgrootte stapsgewijs verlagen
Het systeem SHALL via `Super+Ctrl+Shift+-` de `text-scaling-factor` met 0.1 verlagen, tot een minimum van 0.8.

#### Scenario: Verlagen tot minimum
- **WHEN** gebruiker `Super+Ctrl+Shift+-` indrukt met huidige factor 0.8
- **THEN** blijft de factor 0.8 (geen underflow)

### Requirement: Gebruiker kan tekstgrootte resetten naar standaard
Het systeem SHALL via `Super+Ctrl+Shift+0` de `text-scaling-factor` terugzetten op 1.0.

#### Scenario: Reset vanuit verhoogde waarde
- **WHEN** gebruiker `Super+Ctrl+Shift+0` indrukt met huidige factor 1.4
- **THEN** wordt de factor 1.0 en verschijnt een notificatie "Tekstgrootte: 1.0×"

### Requirement: Visuele bevestiging na schaalwijziging
Het systeem SHALL na elke schaalwijziging een notificatie tonen met de nieuwe factor.

#### Scenario: Notificatie na aanpassing
- **WHEN** de text-scaling-factor wordt gewijzigd
- **THEN** verschijnt een `notify-send` notificatie met de nieuwe waarde, zichtbaar via wayle's notificatie popup
