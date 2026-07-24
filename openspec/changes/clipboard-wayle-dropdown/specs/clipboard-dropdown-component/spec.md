## ADDED Requirements

### Requirement: Clipboard history laden bij openen
Het systeem SHALL de clipboard history laden van `cliphist list` op het moment dat de dropdown zichtbaar wordt (popover map signal).

#### Scenario: Dropdown opent met recente entries
- **WHEN** de gebruiker op het clipboard icoon in de bar klikt
- **THEN** toont de dropdown de meest recente cliphist entries als klikbare rijen

#### Scenario: Lege history
- **WHEN** cliphist geen entries heeft
- **THEN** toont de dropdown een label "Geen clipboard history"

#### Scenario: cliphist niet beschikbaar
- **WHEN** het `cliphist` commando niet gevonden wordt of een fout retourneert
- **THEN** toont de dropdown een label "Clipboard niet beschikbaar" zonder te crashen

### Requirement: Entry selecteren kopieert naar clipboard
Het systeem SHALL bij klik op een entry die entry decoderen via `cliphist decode` en naar het clipboard schrijven via `wl-copy`.

#### Scenario: Klik op tekst-entry
- **WHEN** de gebruiker op een rij in de clipboard dropdown klikt
- **THEN** wordt de bijbehorende cliphist entry gedecodeerd en in het clipboard geplaatst
- **THEN** sluit de dropdown

#### Scenario: Preview truncatie
- **WHEN** een clipboard entry langer is dan 60 tekens
- **THEN** toont de rij een afgekapte preview met ellipsis

### Requirement: Dropdown registratie als "clipboard"
Het systeem SHALL de clipboard dropdown registreren als `"clipboard"` in de wayle dropdown factory registry.

#### Scenario: Activatie via ClickAction
- **WHEN** een module `left-click = "dropdown:clipboard"` heeft
- **THEN** opent de clipboard dropdown bij klikken op die module
