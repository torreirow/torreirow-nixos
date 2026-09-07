# tmux-notepad-binding Specification

## Purpose
Biedt een tmux prefix-keybinding waarmee de gebruiker vanuit elke tmux-sessie snel en
idempotent naar de smug notepad-werkomgeving springt.
## Requirements
### Requirement: Notepad-keybinding start en switcht idempotent

De tmux-configuratie SHALL een prefix-keybinding `N` bevatten die de notepad-werkomgeving
opent. Wanneer de bijbehorende tmux-sessie nog niet bestaat, MUST de binding de smug
`notepad`-layout gedetacheerd starten en er vervolgens naartoe switchen. Wanneer de sessie al
bestaat, MUST de binding er alleen naartoe switchen zonder de layout opnieuw te starten.

#### Scenario: Sessie bestaat nog niet

- **WHEN** de gebruiker prefix + `N` indrukt en er nog geen tmux-sessie `TorrLinny` bestaat
- **THEN** wordt `smug start notepad --detach` uitgevoerd
- **AND** switcht de huidige client naar de sessie `TorrLinny`

#### Scenario: Sessie bestaat al

- **WHEN** de gebruiker prefix + `N` indrukt en de tmux-sessie `TorrLinny` al bestaat
- **THEN** wordt de smug-layout NIET opnieuw gestart
- **AND** switcht de huidige client direct naar de sessie `TorrLinny`

### Requirement: Binding richt zich op de juiste sessienaam

De binding SHALL de sessie identificeren via de naam die `notepad.yml` daadwerkelijk aanmaakt
(`TorrLinny`), niet via de confignaam `notepad`. Zowel de bestaanscontrole als de
switch-actie MUST `TorrLinny` als doel gebruiken.

#### Scenario: Bestaanscontrole gebruikt de echte sessienaam

- **WHEN** de binding controleert of de notepad-sessie al draait
- **THEN** gebruikt de controle de sessienaam `TorrLinny`
- **AND** leidt een reeds draaiende `TorrLinny`-sessie tot alleen switchen (geen dubbele start)

### Requirement: Binding gebruikt switch-client, geen popup

De binding SHALL de gebruiker via `switch-client` volledig naar de notepad-sessie brengen en
MUST NOT een tijdelijke popup-overlay gebruiken, zodat de werkomgeving blijvend is in plaats
van wegklikbaar.

#### Scenario: Gebruiker landt in de volledige sessie

- **WHEN** de gebruiker prefix + `N` indrukt
- **THEN** wordt de client via `switch-client` naar de notepad-sessie gebracht
- **AND** verschijnt er geen tijdelijke popup-overlay bovenop de huidige sessie

