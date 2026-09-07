## MODIFIED Requirements

### Requirement: Notepad-keybinding start en switcht idempotent

De tmux-configuratie SHALL een prefix-keybinding `N` bevatten die schakelt tussen de
notepad-werkomgeving (sessie `TorrLinny`) en de hoofdsessie (`main`). Wanneer de huidige sessie
`TorrLinny` is, MUST de binding naar `main` switchen. Anders MUST de binding naar `TorrLinny`
switchen, en wanneer die sessie nog niet bestaat MUST de binding eerst de smug `notepad`-layout
gedetacheerd starten. Bestaat de `TorrLinny`-sessie al, dan MUST de layout NIET opnieuw gestart
worden.

#### Scenario: Sessie bestaat nog niet

- **WHEN** de gebruiker prefix + `N` indrukt in een sessie die niet `TorrLinny` is en er nog geen
  tmux-sessie `TorrLinny` bestaat
- **THEN** wordt `smug start notepad --detach` uitgevoerd
- **AND** switcht de huidige client naar de sessie `TorrLinny`

#### Scenario: Sessie bestaat al

- **WHEN** de gebruiker prefix + `N` indrukt in een sessie die niet `TorrLinny` is en de
  tmux-sessie `TorrLinny` bestaat al
- **THEN** wordt de smug-layout NIET opnieuw gestart
- **AND** switcht de huidige client naar de sessie `TorrLinny`

#### Scenario: Vanuit TorrLinny terug naar main

- **WHEN** de gebruiker prefix + `N` indrukt terwijl de huidige sessie `TorrLinny` is
- **THEN** switcht de huidige client naar de sessie `main`
- **AND** wordt de smug-layout niet gestart

### Requirement: Binding richt zich op de juiste sessienaam

De binding SHALL de sessie identificeren via de naam die `notepad.yml` daadwerkelijk aanmaakt
(`TorrLinny`), niet via de confignaam `notepad`. Zowel de bestaanscontrole, de detectie van de
huidige sessie als de switch-actie MUST `TorrLinny` als naam gebruiken.

#### Scenario: Bestaanscontrole gebruikt de echte sessienaam

- **WHEN** de binding controleert of de notepad-sessie al draait
- **THEN** gebruikt de controle de sessienaam `TorrLinny`
- **AND** leidt een reeds draaiende `TorrLinny`-sessie tot alleen switchen (geen dubbele start)

#### Scenario: Toggle-detectie gebruikt de echte sessienaam

- **WHEN** de binding bepaalt of ze naar `main` of naar `TorrLinny` moet switchen
- **THEN** vergelijkt ze de huidige sessienaam met `TorrLinny`
