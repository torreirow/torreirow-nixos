## ADDED Requirements

### Requirement: Cycle door power profiles via dashboard knop
De dashboard quick actions knop SHALL door alle beschikbare power profiles fietsen bij elke klik, in volgorde PowerSaver → Balanced → Performance → PowerSaver. Als Performance niet beschikbaar is op het systeem, SHALL de knop alleen tussen PowerSaver en Balanced wisselen.

#### Scenario: Klik vanuit Balanced naar PowerSaver
- **WHEN** het actieve profiel is `Balanced` en de gebruiker klikt op de knop
- **THEN** wordt `PowerSaver` het actieve profiel

#### Scenario: Klik vanuit PowerSaver naar Performance (beschikbaar)
- **WHEN** het actieve profiel is `PowerSaver`, Performance is beschikbaar, en de gebruiker klikt
- **THEN** wordt `Performance` het actieve profiel

#### Scenario: Klik vanuit PowerSaver naar Balanced (Performance niet beschikbaar)
- **WHEN** het actieve profiel is `PowerSaver`, Performance is NIET beschikbaar, en de gebruiker klikt
- **THEN** wordt `Balanced` het actieve profiel

#### Scenario: Klik vanuit Performance naar Balanced
- **WHEN** het actieve profiel is `Performance` en de gebruiker klikt
- **THEN** wordt `Balanced` het actieve profiel

### Requirement: Knop toont dynamisch het actieve profiel
De knop SHALL het actieve power profiel weergeven via een icoon en een label dat mee verandert met het profiel.

#### Scenario: PowerSaver actief — knop toont leaf icoon
- **WHEN** het actieve profiel is `PowerSaver`
- **THEN** toont de knop het icoon `ld-leaf-symbolic` en het label "Power Saver"

#### Scenario: Balanced actief — knop toont scale icoon
- **WHEN** het actieve profiel is `Balanced`
- **THEN** toont de knop het icoon `ld-scale-symbolic` en het label "Balanced"

#### Scenario: Performance actief — knop toont rocket icoon
- **WHEN** het actieve profiel is `Performance`
- **THEN** toont de knop het icoon `ld-rocket-symbolic` en het label "Performance"

### Requirement: Balanced heeft visuele uit-staat, overige profielen aan-staat
De knop SHALL de CSS class `active` tonen wanneer het actieve profiel NIET `Balanced` is, en de class weglaten wanneer `Balanced` actief is.

#### Scenario: PowerSaver actief — knop heeft active class
- **WHEN** het actieve profiel is `PowerSaver`
- **THEN** heeft de knop de CSS class `active`

#### Scenario: Balanced actief — knop heeft geen active class
- **WHEN** het actieve profiel is `Balanced`
- **THEN** heeft de knop GEEN CSS class `active`

#### Scenario: Performance actief — knop heeft active class
- **WHEN** het actieve profiel is `Performance`
- **THEN** heeft de knop de CSS class `active`

### Requirement: Knop reflecteert externe profielwijzigingen
De knop SHALL ook updaten wanneer het actieve power profiel buiten de dashboard knop om wordt gewijzigd (bijv. via de battery dropdown of CLI).

#### Scenario: Profiel gewijzigd via battery dropdown
- **WHEN** de gebruiker het profiel wijzigt via de battery dropdown segmented control
- **THEN** updaten icoon, label en active-staat van de dashboard knop naar het nieuwe profiel
