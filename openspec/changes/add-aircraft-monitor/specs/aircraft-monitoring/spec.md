## Purpose

De aircraft-monitoring capability laat Home Assistant periodiek ADS-B-data ophalen rond een
geconfigureerde GPS-locatie, per vliegtuig de voorspelde closest approach berekenen, relevante
entities aanbieden en een dedup-vrij event afvuren wanneer een toestel binnen een instelbare
afstand van die locatie zal komen — volledig via de UI configureerbaar en geschikt voor meerdere
locaties.

## ADDED Requirements

### Requirement: ADS-B-data ophalen via ADSB.lol

De integratie SHALL periodiek vliegtuigdata ophalen van de publieke ADSB.lol v2 API voor een
geconfigureerde locatie en zoekradius, zonder API-key, met de radius omgerekend van kilometers naar
nautical miles (`radius_nm = radius_km / 1.852`). Het ophalen SHALL non-blocking gebeuren en centraal
door één coordinator per config-entry, niet per entity.

#### Scenario: Succesvolle ophaalronde

- **WHEN** de coordinator een pollronde uitvoert voor een locatie met radius 20 km
- **THEN** SHALL de integratie de endpoint `https://api.adsb.lol/v2/lat/{lat}/lon/{lon}/dist/{nm}` bevragen met `nm ≈ 10.8`
- **AND** SHALL de teruggegeven vliegtuiglijst (`ac`) beschikbaar stellen aan de entities

#### Scenario: Polling-interval is configureerbaar en respecteert de event loop

- **WHEN** de gebruiker een polling-interval van 10 seconden instelt
- **THEN** SHALL de coordinator elke ~10 seconden pollen zonder `time.sleep()` of een eigen thread
- **AND** SHALL geen blocking HTTP-call in de event loop worden uitgevoerd

### Requirement: Robuuste verwerking van onvolledige of foutieve data

De integratie SHALL ontbrekende, `null` of ongeldige velden veilig verwerken en SHALL blijven
functioneren wanneer de API tijdelijk onbereikbaar is of ongeldige/lege data teruggeeft. Een tijdelijke
fout SHALL de integratie niet laten crashen. De volledige JSON-response SHALL niet op INFO-niveau
worden gelogd.

#### Scenario: Vliegtuig zonder track of snelheid

- **WHEN** een vliegtuigrecord `track` of `gs` mist
- **THEN** SHALL geen voorspelling worden berekend voor dat vliegtuig
- **AND** SHALL de closest approach gelijk zijn aan de huidige afstand met een onbepaalde ETA
- **AND** SHALL het vliegtuig niet als "approaching" worden gemarkeerd

#### Scenario: alt_baro als "ground" of ontbrekend

- **WHEN** een record `alt_baro` met de waarde `"ground"` of geen hoogte bevat
- **THEN** SHALL de integratie dit veilig interpreteren (bijv. als hoogte 0) zonder fout
- **AND** SHALL het record niet leiden tot een uitzondering in de verwerking

#### Scenario: API tijdelijk onbereikbaar

- **WHEN** een pollronde een connection error, timeout, HTTP-fout of ongeldige JSON oplevert
- **THEN** SHALL de integratie de fout afhandelen via de standaard coordinator-foutafhandeling
- **AND** SHALL de laatst bekende geldige state behouden blijven
- **AND** SHALL een volgende geslaagde pollronde de state weer bijwerken

### Requirement: Voorspelde closest approach

De integratie SHALL voor elk relevant vliegtuig op basis van huidige positie, grondsnelheid en track
de minimale afstand tot de doellocatie berekenen die binnen het venster `prediction_time` bereikt
wordt, samen met de tijd tot die closest approach. De berekening SHALL geografisch correct zijn voor
korte afstanden (lokaal tangentieel vlak) en SHALL correct omgaan met koersen rond 359°→0°.

#### Scenario: Recht op de locatie af

- **WHEN** een vliegtuig recht richting de doellocatie vliegt
- **THEN** SHALL de voorspelde closest approach ongeveer 0 meter zijn
- **AND** SHALL het vliegtuig als "naar de locatie toe bewegend" worden herkend

#### Scenario: Parallel langs de locatie

- **WHEN** een vliegtuig langs de locatie vliegt met de loodrechte voet binnen het prediction-venster
- **THEN** SHALL de voorspelde closest approach ongeveer de loodrechte afstand zijn

#### Scenario: Van de locatie af

- **WHEN** een vliegtuig van de locatie weg vliegt
- **THEN** SHALL de voorspelde closest approach ongeveer de huidige afstand zijn
- **AND** SHALL het vliegtuig niet als "naar de locatie toe bewegend" worden herkend

#### Scenario: Koers 359° naar 0°

- **WHEN** een vliegtuig een track nabij 359° of 0° heeft
- **THEN** SHALL de berekening geen fout of discontinuïteit veroorzaken

### Requirement: Lokale filtering van relevante vliegtuigen

Na het ophalen SHALL de integratie lokaal filteren op minimum hoogte, maximum hoogte en minimum
snelheid. Alleen vliegtuigen die aan deze criteria voldoen SHALL als relevant worden beschouwd voor de
entities en de approaching-detectie.

#### Scenario: Vliegtuig onder de minimumsnelheid

- **WHEN** een vliegtuig een grondsnelheid heeft onder de geconfigureerde minimumsnelheid
- **THEN** SHALL het vliegtuig niet als relevant worden meegeteld

#### Scenario: Vliegtuig buiten de hoogtegrenzen

- **WHEN** een vliegtuig een hoogte heeft onder de minimum- of boven de maximumhoogte
- **THEN** SHALL het vliegtuig niet als relevant worden meegeteld

### Requirement: Approaching-detectie

De integratie SHALL een vliegtuig als "approaching" markeren wanneer én de voorspelde closest approach
kleiner of gelijk is aan `alert_distance`, én de tijd tot closest approach kleiner of gelijk is aan
`prediction_time`, én het vliegtuig daadwerkelijk naar de locatie toe beweegt.

#### Scenario: Alle voorwaarden vervuld

- **WHEN** een relevant vliegtuig een voorspelde closest approach ≤ `alert_distance` heeft binnen `prediction_time` en naar de locatie toe beweegt
- **THEN** SHALL het vliegtuig als "approaching" worden gemarkeerd

#### Scenario: Binnen afstand maar wegbewegend

- **WHEN** een vliegtuig zich binnen `alert_distance` bevindt maar van de locatie weg beweegt
- **THEN** SHALL het vliegtuig niet als "approaching" worden gemarkeerd

### Requirement: Home Assistant entities

De integratie SHALL per config-entry entities aanbieden: een sensor met het aantal relevante
vliegtuigen, een sensor voor het dichtstbijzijnde relevante vliegtuig (afstand + attributen), een
sensor voor het vliegtuig met de meest nabije voorspelde closest approach (afstand/ETA + attributen),
en een binary_sensor die `on` is zolang minstens één vliegtuig approaching is. Entities SHALL unieke
identifiers per config-entry gebruiken zodat meerdere locaties naast elkaar bestaan.

#### Scenario: Aircraft count sensor

- **WHEN** er drie relevante vliegtuigen binnen de zoekradius zijn
- **THEN** SHALL de aircraft-count sensor de waarde 3 tonen

#### Scenario: Binary sensor bij approaching vliegtuig

- **WHEN** minstens één vliegtuig als "approaching" is gemarkeerd
- **THEN** SHALL de binary_sensor `on` zijn met attributen callsign, icao, closest_distance, eta, altitude, speed, track

#### Scenario: Geen approaching vliegtuigen

- **WHEN** geen enkel vliegtuig approaching is
- **THEN** SHALL de binary_sensor `off` zijn

### Requirement: Approaching-event met duplicate-prevention

De integratie SHALL een custom event `aircraft_monitor.aircraft_approaching` afvuren wanneer een
vliegtuig nieuw de alert-zone binnenkomt. Hetzelfde vliegtuig (geïdentificeerd via `hex`) SHALL tijdens
dezelfde nadering niet herhaaldelijk een event veroorzaken. Nadat het vliegtuig de zone heeft verlaten
(met hysterese) of gedurende een cooldown niet meer nadert, SHALL een nieuwe nadering opnieuw een event
mogen afvuren. De eventdata SHALL minimaal bevatten: icao, callsign, latitude, longitude, altitude_ft,
speed_knots, track, current_distance_m, closest_distance_m, eta_seconds.

#### Scenario: Eerste keer approaching vuurt één event

- **WHEN** een vliegtuig voor het eerst de alert-voorwaarden vervult
- **THEN** SHALL precies één `aircraft_monitor.aircraft_approaching` event worden afgevuurd met de vereiste eventdata

#### Scenario: Aanhoudende nadering vuurt geen extra events

- **WHEN** hetzelfde vliegtuig bij opeenvolgende pollrondes approaching blijft
- **THEN** SHALL geen aanvullend event worden afgevuurd

#### Scenario: Opnieuw naderen na verlaten van de zone

- **WHEN** een vliegtuig de alert-zone heeft verlaten en later opnieuw de alert-voorwaarden vervult
- **THEN** SHALL opnieuw één event worden afgevuurd

### Requirement: UI-configuratie met validatie en meerdere locaties

De integratie SHALL volledig via de HA-UI toe te voegen en te configureren zijn (config-flow), met
aanpasbare tunables via een options-flow. De configureerbare parameters SHALL zijn: latitude,
longitude, search radius, alert distance, prediction time, polling interval, minimum hoogte, maximum
hoogte en minimum snelheid. De locatie en tunables SHALL nooit hardcoded zijn; de opgegeven waarden
zijn uitsluitend defaults. Meerdere config-entries (locaties) SHALL naast elkaar mogelijk zijn.

#### Scenario: Ongeldige coördinaten worden geweigerd

- **WHEN** de gebruiker een latitude buiten [-90, 90] of longitude buiten [-180, 180] invoert
- **THEN** SHALL de config-flow de invoer weigeren met een validatiefout

#### Scenario: Inconsistente grenzen worden geweigerd

- **WHEN** de gebruiker een minimum hoogte groter dan de maximum hoogte, een radius ≤ 0, een alert_distance ≤ 0, een prediction_time ≤ 0, een polling-interval < 5, of een minimum snelheid < 0 invoert
- **THEN** SHALL de config-flow de invoer weigeren met een validatiefout

#### Scenario: Een andere locatie configureren

- **WHEN** de gebruiker een tweede entry toevoegt met andere coördinaten en radius
- **THEN** SHALL een tweede onafhankelijke set entities voor die locatie ontstaan zonder de eerste te beïnvloeden

#### Scenario: Defaults bij nieuwe entry

- **WHEN** de gebruiker een nieuwe entry start zonder waarden aan te passen
- **THEN** SHALL de defaults worden voorgesteld: latitude 52.2946, longitude 5.5989, radius 20 km, alert_distance 250 m, prediction_time 180 s, polling 10 s, min hoogte 0 ft, max hoogte 15000 ft, min snelheid 25 kt
