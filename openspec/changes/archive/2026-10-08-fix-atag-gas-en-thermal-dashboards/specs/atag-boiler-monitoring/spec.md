# Spec Delta

## Purpose

Legt vast hoe de ATAG One CV-ketel- en verwarmingsdata betrouwbaar wordt gevisualiseerd en
bewaakt in Grafana en Prometheus: welke databron per grootheid leidend is, hoe onbetrouwbare of
structureel lege sensoren worden behandeld, en hoe tijdgebonden panelen zich tot de tijdkiezer
verhouden.

## ADDED Requirements

### Requirement: Gasverbruik uit de fysieke gasmeter

Gasverbruik-visualisaties SHALL de fysieke P1/DSMR-huisgasmeter
(`sensor.gas_meter_gasverbruik`) als bron gebruiken, NIET de boiler-eigen schatting
`sensor.atag_one_gas`. De boiler-schatting is aantoonbaar onbetrouwbaar (ordegrootte te laag) en
SHALL niet in enig gas-paneel voorkomen.

#### Scenario: Gasverbruik-paneel toont realistische waarde

- **WHEN** een paneel het gasverbruik per tijdseenheid of cumulatief toont
- **THEN** de query selecteert `homeassistant_sensor_gas_mu0xb3{entity="sensor.gas_meter_gasverbruik"}`
- **AND** de getoonde m³/h ligt in de orde van het aantal branduren maal het reële branderdebiet
  (richtwaarde ~1 m³/h voor deze combi), niet een factor ~10 lager

#### Scenario: Gas-versus-buitentemperatuur-correlatie

- **WHEN** het paneel dat gasverbruik tegen buitentemperatuur afzet rendert
- **THEN** de gas-serie komt uit `sensor.gas_meter_gasverbruik`, niet uit `sensor.atag_one_gas`

### Requirement: Buitentemperatuur gefilterd op plausibel bereik

Elke query op een buitentemperatuur-sensor SHALL bogus metingen uitsluiten met een
ondergrensfilter (`> -40`), zodat een enkele onmogelijke waarde (zoals een −100 °C-spike)
gemiddelden, minimums en assen niet verstoort.

#### Scenario: Bogus −100 °C-meting beïnvloedt statistiek niet

- **WHEN** de buitentemperatuur-reeks een onmogelijke waarde onder −40 °C bevat
- **THEN** die waarde valt buiten elke buitentemp-query en telt niet mee in min/gemiddelde/as-schaal
- **AND** het getoonde minimum reflecteert de werkelijke laagste plausibele meting

### Requirement: Geen visualisatie of alert voor structureel lege sensoren

Panelen en alertregels SHALL niet gebaseerd zijn op ATAG-sensoren die op deze ketel structureel
0 blijven en niet ondersteund worden: branderstarts, warmwaterdoorstroming, opwarmtijd,
DHW-waterdruk en boiler-capaciteit. Een alert waarvan de conditie per definitie nooit waar kan
worden SHALL niet bestaan.

#### Scenario: Lege-sensor-paneel is verwijderd

- **WHEN** een sensor over een representatief venster uitsluitend 0 teruggeeft
- **THEN** er is geen paneel dat die sensor als enige databron toont

#### Scenario: Intermitterende sensor telt niet als leeg

- **WHEN** een sensor meestal 0 is maar over het venster ook een niet-nul-waarde heeft gehad
  (zoals het CV-aanvoersetpoint `setpoint_hotwater` dat tijdens het stoken naar ~40 °C loopt)
- **THEN** die sensor geldt niet als structureel leeg en mag behouden blijven

#### Scenario: Nooit-vurende alert is verwijderd

- **WHEN** een alertconditie een `increase()` over een constant-0 sensor is
- **THEN** die alertregel bestaat niet in de Prometheus-alertconfiguratie

### Requirement: Brandtijd uit de brandurenteller

Afgeleide brandtijd SHALL berekend worden uit de cumulatieve brandurenteller
(`sensor.atag_one_branduren`), NIET uit het periodiek gesamplede brander-percentage. Het
percentage wordt te grof bemonsterd en mist korte tapwaterbeurten, wat tot een te lage brandtijd
leidt.

#### Scenario: Brandtijd over een venster

- **WHEN** een paneel of berekening de brandtijd over een periode nodig heeft
- **THEN** die is afgeleid van het verschil in de brandurenteller over dat venster

### Requirement: Tijdgebonden statistiekpanelen volgen de tijdkiezer

Panelen die een statistiek over "de gekozen periode" tonen SHALL het dashboard-tijdbereik volgen
via `$__range`, en SHALL geen vast venster (zoals `[24h]` of `[24h:5m]`) hardcoden. Een
paneeltitel SHALL geen vaste periode suggereren die de query niet afdwingt.

#### Scenario: Statistiek over meerdere weken bekijken

- **WHEN** de gebruiker het dashboard-tijdbereik op meerdere weken zet
- **THEN** de comfort-, accuratesse- en stabiliteitspanelen herberekenen over dat hele bereik
- **AND** geen van die panelen rekent stil door over slechts 24 uur

### Requirement: Rendementsindicatie uitsluitend op retourtemperatuur

De rendements-/condensatie-indicatie van de ketel SHALL uitsluitend gebaseerd zijn op de
CV-retourtemperatuur (`sensor.atag_one_cv_retour_temp`), waarbij een lagere retour een beter
(condenserend) rendement betekent. Noch de aanvoer-minus-retour-delta, noch
`sensor.atag_one_boiler_retour_temp` SHALL als rendements-/CV-retourbron dienen.

#### Scenario: Retourtemperatuur als rendementsmaat

- **WHEN** een paneel het ketelrendement of de condensatie-indicatie toont
- **THEN** de databron is `sensor.atag_one_cv_retour_temp` en niets anders
- **AND** er bestaat geen paneel dat rendement als aanvoer−retour-delta weergeeft
- **AND** geen paneel gebruikt `sensor.atag_one_boiler_retour_temp`

### Requirement: Condensatie-bewaking op 55 °C retour

Het retourtemperatuur-paneel SHALL een drempellijn op 55 °C tonen als condensatiegrens, en er
SHALL een alertregel zijn die waarschuwt wanneer de CV-retour (`sensor.atag_one_cv_retour_temp`)
langdurig boven 55 °C blijft — het punt waarboven de ketel niet meer condenseert. Deze bewaking is
vooral relevant na de overstap naar kamergeregeld stoken (room_regulation).

#### Scenario: Retour blijft onder de condensatiegrens

- **WHEN** de CV-retour onder 55 °C blijft
- **THEN** toont het paneel de waarde onder de 55 °C-drempellijn en vuurt de alert niet

#### Scenario: Retour overschrijdt de condensatiegrens

- **WHEN** de CV-retour langdurig boven 55 °C komt
- **THEN** vuurt de condensatie-alert, als signaal dat de ketel niet meer condenseert

### Requirement: Kalibratiepaneel buitensensor

Er SHALL een paneel zijn dat het verschil tussen de ATAG-kamertemperatuur en de ATAG-buitensensor
(`sensor.atag_one_kamer_temp - sensor.atag_one_buiten_temp`) over de tijd toont, zodat de
kalibratie-afwijking te volgen is zolang de buitensensor nog binnen hangt. De buitensensor-term
SHALL hetzelfde `> -40`-filter dragen als de overige buitentemp-queries.

#### Scenario: Kalibratie-afwijking volgen

- **WHEN** de buitensensor binnen is geplaatst voor kalibratie
- **THEN** toont het paneel het verschil kamer − buiten over de gekozen periode
- **AND** een verschil richting 0 duidt op gelijke omgeving; een stabiel verschil is de offset

### Requirement: Warmhoud-/warmtewisselaarpaneel

Er SHALL een paneel zijn dat de warmhoud-/warmtewisselaartemperatuur
(`sensor.atag_one_boiler_retour_temp`) over de tijd toont, zodat de comfort-/eco-warmhoudbrandjes
zichtbaar zijn — de korte brandcycli die de warmtewisselaar warm houden voor snel warm water en een
deel van de branduren verklaren, ook zonder tapvraag. Het paneel SHALL deze grootheid niet als
CV-retour of rendementsmaat labelen.

#### Scenario: Warmhoudgedrag zichtbaar

- **WHEN** de ketel in comfort-/warmhoudstand de warmtewisselaar warm houdt
- **THEN** toont het paneel het zaagtandpatroon van de warmhoudtemperatuur (~47–55 °C)
- **AND** de reeks is herkenbaar los van het CV-water, dat ondertussen laag kan blijven

### Requirement: CV-aanvoersetpoint in CV-temperatuurgrafiek

De CV-temperatuur-timeseries SHALL het CV-aanvoersetpoint (`sensor.atag_one_setpoint_hotwater`,
ondanks de naam het CV-setpoint) als reeks tonen, zodat zichtbaar is of de aanvoer condensatie-
vriendelijk laag blijft. De reeks SHALL als aanvoersetpoint gelabeld worden, niet als
warmwatersetpoint.

#### Scenario: Aanvoersetpoint volgen tijdens stoken

- **WHEN** de ketel voor de verwarming stookt
- **THEN** toont de CV-temperatuurgrafiek het aanvoersetpoint (bijv. ~40 °C) naast de
  gemeten aanvoer- en retourtemperatuur
- **AND** een laag setpoint is zichtbaar als gunstig voor condenseren
