## Purpose

Voorziet het temperatuur/vocht-dashboard van een neerslag-indicator die Buienradar's
punt-nowcast combineert met een lokaal berekend dauwpunt, zodat zichtbaar is of het regent,
gaat regenen, of dat de lucht slechts verzadigd is (mist/dauw).

## ADDED Requirements

### Requirement: Neerslagdata beschikbaar via Buienladar-nowcast

Het systeem SHALL neerslagdata beschikbaar stellen op basis van Buienradar's radar-nowcast voor
de eigen GPS-locatie, zodat de data geldig is voor de woonplaats ongeacht de afstand tot het
dichtstbijzijnde meetstation. De data SHALL de huidige neerslagintensiteit (mm/h) en de verwachte
totale neerslag over de komende twee uur (mm) omvatten.

#### Scenario: Huidige neerslag is beschikbaar

- **WHEN** de Buienradar-integratie actief is en peilt
- **THEN** is de huidige neerslagintensiteit in mm/h beschikbaar als een sensor met device_class
  `precipitation_intensity`

#### Scenario: Nowcast voor de komende twee uur is beschikbaar

- **WHEN** de integratie is geconfigureerd met een tijdvenster van 120 minuten
- **THEN** is de verwachte totale neerslag (mm) over dat venster beschikbaar als een sensor met
  device_class `precipitation`
- **AND** is de verwachte gemiddelde intensiteit (mm/h) over dat venster beschikbaar

#### Scenario: Nowcast geldt voor de eigen locatie, niet een ver station

- **WHEN** er geen Buienradar-meetstation dicht bij de woonplaats ligt
- **THEN** SHALL de neerslag-nowcast toch de eigen GPS-coördinaten als peilpunt gebruiken

### Requirement: Lokaal dauwpunt afgeleid van de buitensensor

Het systeem SHALL het dauwpunt en de dauwpunt-spread (buitentemperatuur minus dauwpunt) berekenen
uit de bestaande buiten-temperatuur- en -luchtvochtigheidssensor, zodat verzadiging van de lucht
lokaal detecteerbaar is, ook zonder extra hardware.

#### Scenario: Dauwpunt wordt berekend uit temp en vocht

- **WHEN** de buiten-temperatuur en relatieve luchtvochtigheid bekend zijn
- **THEN** SHALL het dauwpunt in °C worden afgeleid via de Magnus-formule
- **AND** SHALL de dauwpunt-spread (temp − dauwpunt) beschikbaar zijn

#### Scenario: Bronsensor is tijdelijk onbeschikbaar

- **WHEN** de buiten-temperatuur- of vochtwaarde ontbreekt of ongeldig is
- **THEN** SHALL de dauwpunt-sensor geen misleidende numerieke waarde tonen maar onbeschikbaar zijn

### Requirement: Samengestelde neerslag-indicator met eerlijke toestanden

Het systeem SHALL één samengestelde indicator leveren die de radar-nowcast en de dauwpunt-heuristiek
combineert tot een begrijpelijke toestand, waarbij radardata leidend is voor daadwerkelijke neerslag
en de dauwpunt-heuristiek uitsluitend verzadiging aanduidt die de radar niet ziet.

#### Scenario: Het regent nu

- **WHEN** de huidige neerslagintensiteit boven de "regent"-drempel ligt
- **THEN** SHALL de indicator de toestand `Regent` tonen

#### Scenario: Bui op komst

- **WHEN** het niet regent maar de verwachte neerslag over de komende twee uur boven de drempel ligt
- **THEN** SHALL de indicator de toestand `Bui op komst` tonen

#### Scenario: Lucht verzadigd zonder radarregen

- **WHEN** de radar geen (verwachte) neerslag toont
- **AND** de dauwpunt-spread onder de drempel ligt EN de relatieve luchtvochtigheid boven de drempel
- **THEN** SHALL de indicator de toestand `Verzadigd` tonen (mist/dauw/mogelijke motregen onder de radar)

#### Scenario: Droog

- **WHEN** geen van de bovenstaande voorwaarden geldt
- **THEN** SHALL de indicator de toestand `Droog` tonen

### Requirement: Neerslag zichtbaar in het Grafana-dashboard

Het systeem SHALL de neerslag- en dauwpuntdata tonen in het bestaande dashboard "Temperatuur &
Luchtvochtigheid", zonder wijziging aan de Prometheus-export.

#### Scenario: Neerslagpanelen zijn zichtbaar

- **WHEN** het dashboard wordt geopend
- **THEN** SHALL een rij "Neerslag" de huidige neerslag (mm/h), de verwachting over twee uur (mm)
  en een neerslag-verloopgrafiek tonen

#### Scenario: Dauwpunt zichtbaar bij bestaande grafieken

- **WHEN** het dashboard wordt geopend
- **THEN** SHALL het dauwpunt (en/of de spread) als extra lijn bij de bestaande temperatuur- of
  luchtvochtigheidsgrafiek te zien zijn

#### Scenario: Nieuwe sensoren verschijnen zonder exportwijziging

- **WHEN** de nieuwe neerslag- en dauwpuntsensoren in Home Assistant bestaan
- **THEN** SHALL Prometheus ze scrapen zonder aanpassing van de include-filters
