## Purpose

Interactieve native GTK4 dropdown voor het beheren van Solidtime tijdregistraties: starten, stoppen, project selecteren en recente entries bekijken — visueel consistent met de bestaande wayle dropdowns.

## ADDED Requirements

### Requirement: Dropdown toont huidige timer status
De dropdown SHALL een statuskaart tonen met: een visuele indicator (pulserende stip wanneer running), het label "Recording" of "Idle", een subtext met actieve beschrijving en project, en de verstreken tijd als `HH:MM:SS` die elke seconde bijwerkt.

#### Scenario: Timer loopt
- **WHEN** de dropdown open is en een timer actief is
- **THEN** toont de statuskaart "Recording", de actieve beschrijving + project, en een oplopende `HH:MM:SS` teller
- **THEN** pulseert de status stip

#### Scenario: Geen timer actief
- **WHEN** de dropdown open is en geen timer loopt
- **THEN** toont de statuskaart "Idle" en `00:00:00`

### Requirement: Gebruiker kan een nieuwe timer starten
De dropdown SHALL een tekstveld bieden voor een beschrijving en een project picker. Bij activeren van de start knop (of Enter in het beschrijvingsveld) SHALL `soltty start "<beschrijving>" -p "<project>" -y` worden aangeroepen. Een lopende timer wordt automatisch gestopt.

#### Scenario: Timer starten met beschrijving en project
- **WHEN** de gebruiker een beschrijving invoert, een project selecteert en op "Start timer" klikt
- **THEN** wordt `soltty start` aangeroepen met de opgegeven beschrijving en project
- **THEN** vernieuwen statuskaart en bar module binnen 2 seconden

#### Scenario: Timer starten zonder project
- **WHEN** de gebruiker een beschrijving invoert zonder project te selecteren en start klikt
- **THEN** wordt `soltty start` aangeroepen zonder `--project` argument

#### Scenario: Enter in beschrijvingsveld
- **WHEN** de gebruiker Enter indrukt in het beschrijvingsveld
- **THEN** wordt de timer gestart met de huidige beschrijving en geselecteerd project

### Requirement: Gebruiker kan de lopende timer stoppen
De dropdown SHALL een stop knop tonen wanneer een timer loopt. Bij klikken SHALL `soltty stop` worden aangeroepen.

#### Scenario: Timer stoppen
- **WHEN** een timer loopt en de gebruiker op "Stop timer" klikt
- **THEN** wordt `soltty stop` aangeroepen
- **THEN** vernieuwen statuskaart en bar module binnen 2 seconden

### Requirement: Project picker toont beschikbare projecten met zoekfunctie
De dropdown SHALL een GTK4 `DropDown` widget bieden die de projecten ophaalt via `soltty list projects --json`. De picker SHALL zoeken ondersteunen. De picker SHALL bijgewerkt worden bij elke keer dat de dropdown wordt geopend.

#### Scenario: Projecten laden
- **WHEN** de dropdown wordt geopend
- **THEN** wordt `soltty list projects --json` aangeroepen
- **THEN** worden de projectnamen beschikbaar in de project picker

#### Scenario: Project zoeken
- **WHEN** de gebruiker tekst typt in de project picker
- **THEN** worden alleen projecten getoond die de zoektekst bevatten

### Requirement: Dropdown toont recente tijdregistraties
De dropdown SHALL de 4 meest recente tijdregistraties tonen via `soltty list --json --limit 4`, met starttijd, duur, en beschrijving.

#### Scenario: Recente entries bij openen
- **WHEN** de dropdown wordt geopend
- **THEN** worden de 4 meest recente entries geladen en weergegeven

#### Scenario: Geen recente entries
- **WHEN** geen eerdere tijdregistraties bestaan
- **THEN** toont de dropdown geen recente sectie of een leeg-state bericht

### Requirement: Dropdown toont verbindingsstatus
De dropdown SHALL een visuele indicator tonen die aangeeft of `soltty` bereikbaar is (connected/disconnected).

#### Scenario: Verbinding OK
- **WHEN** `soltty current --json` succesvol retourneert
- **THEN** toont de header een groene verbindingsstip

#### Scenario: Verbinding verbroken
- **WHEN** `soltty` een fout retourneert of niet beschikbaar is
- **THEN** toont de header een rode verbindingsstip

### Requirement: Dropdown past in de wayle visuele stijl
De dropdown SHALL de `Dropdown`, `DropdownHeader` en `DropdownContent` GTK4 template widgets van wayle gebruiken, consistent met weather en planify dropdowns. CSS SHALL gebruik maken van wayle design tokens.

#### Scenario: Visuele consistentie
- **WHEN** de solidtime dropdown naast de weather dropdown wordt geopend
- **THEN** zijn de border radius, achtergrondkleur, header stijl en spacings visueel consistent
