## Purpose

Native wayle bar module die de actieve Solidtime timer live weergeeft in de statusbalk en toegang biedt tot de solidtime dropdown.

## ADDED Requirements

### Requirement: Bar module toont live timer status
De bar module SHALL de lopende timer weergeven als `⏱ HH:MM:SS` (zero-padded), bijgewerkt elke seconde via een lokale berekening op basis van de gecachete starttijd. Wanneer geen timer loopt SHALL het label `⏱` tonen zonder tijdweergave.

#### Scenario: Timer loopt
- **WHEN** een Solidtime timer actief is
- **THEN** toont de bar knop `⏱ HH:MM:SS` dat elke seconde oploopt

#### Scenario: Geen timer actief
- **WHEN** geen Solidtime timer loopt
- **THEN** toont de bar knop `⏱` zonder tijdweergave

#### Scenario: soltty niet bereikbaar
- **WHEN** de `soltty` binary niet beschikbaar is of een fout retourneert
- **THEN** toont de bar knop `⏱` en verdwijnt niet uit de balk

### Requirement: Bar module pollt soltty periodiek
De bar module SHALL `soltty current --json` aanroepen om de timer status op te halen. Polling interval SHALL niet korter zijn dan 5 seconden. De elapsed berekening tussen polls SHALL lokaal plaatsvinden op basis van de gecachete `start` timestamp.

#### Scenario: Poll cycle
- **WHEN** de bar module actief is
- **THEN** wordt `soltty current --json` minimaal elke 5 seconden aangeroepen om status te synchroniseren

#### Scenario: Elapsed berekening
- **WHEN** een timer loopt en de laatste poll `start` timestamp bevat
- **THEN** berekent de module elapsed lokaal elke seconde zonder extra CLI calls

### Requirement: Bar module is klikbaar en opent dropdown
Een klik op de bar knop SHALL de `solidtime` dropdown openen of sluiten (toggle). Het klikgedrag SHALL configureerbaar zijn via `left-click` in de wayle config.

#### Scenario: Linker klik opent dropdown
- **WHEN** de gebruiker links klikt op de solidtime bar knop
- **THEN** wordt de `solidtime` dropdown geopend (of gesloten als al open)

### Requirement: Bar module is configureerbaar via wayle config
De module SHALL beschikbaar zijn als `"solidtime"` in de bar layout array van `wayle.toml`. Kleur, icoon, label zichtbaarheid en klikacties SHALL configureerbaar zijn via `[modules.solidtime]`.

#### Scenario: Plaatsing in layout
- **WHEN** `"solidtime"` staat in de `center`/`left`/`right` array van een bar layout
- **THEN** verschijnt de solidtime knop op die positie in de balk
