# Tasks

## 1. Gasmeting op de P1-meter

- [x] 1.1 In `atag-boiler.json` paneel 6 "Gas Verbruik (m³/uur)" de query van
  `sensor.atag_one_gas` naar `sensor.gas_meter_gasverbruik` zetten; verifieer dat de getoonde
  waarde in de orde ~1 m³/h ligt (niet ~0,1) tijdens een brandinterval.
- [x] 1.2 In `atag-boiler.json` paneel 23 "Buitentemperatuur vs Gasverbruik Correlatie" refId B
  (`increase(... atag_one_gas ...[1h])`) naar `sensor.gas_meter_gasverbruik` zetten; verifieer dat
  de rechter-as nu reële m³-waarden toont.
- [x] 1.3 Controleer dat `sensor.atag_one_gas` nergens meer in `atag-boiler.json` voorkomt
  (`grep -c atag_one_gas atag-boiler.json` → 0).

## 2. Buitentemp-outlierfilter

- [x] 2.1 `> -40`-filter toevoegen aan de buitentemp-query's in `atag-boiler.json`: paneel 2
  (gauge), paneel 23 refId A, paneel 5 refId B, en paneel 10 (gemiddelde buitentemp).
- [x] 2.2 `> -40`-filter toevoegen aan `atag-thermal-dashboard.json` paneel 1 refId C ("Buiten").
- [x] 2.3 Verifieer met Prometheus dat `min_over_time((buiten_temp > -40)[14d:1m])` een plausibele
  waarde geeft (≈ 8–9 °C) en de raw-reeks nog −100 bevat (filter doet dus wat), en controleer dat
  elke buitentemp-query in beide bestanden de filter draagt.

## 3. Dode panelen en dode alert verwijderen

- [x] 3.1 Uit `atag-boiler.json` de panelen "Brander Starts", "Opwarmtijd Kamer" en "Warm Water
  Flow Rate" verwijderen (match op titel + type, niet blind op id — ids 11/12/13 worden hergebruikt
  door rows). Verifieer dat `lumc_brander_starts`, `cv_tijd_naar_temp` en `dhw_flow_rate` niet meer
  in het bestand staan.
- [x] 3.2 Uit `atag-thermal-dashboard.json` het paneel "Brander Cycling Efficiency" verwijderen;
  verifieer dat `lumc_brander_starts` niet meer in het bestand staat.
- [x] 3.3 Controleer dat het brander-percentage (`sensor.atag_one_brander`) nog wél aanwezig is in
  `atag-boiler.json` (panelen "Brander Percentage" en "Brander Activiteit" blijven).
- [x] 3.4 Guard structureel lege sensoren: verifieer dat `dhw_waterdruk`, `boiler_capaciteit` en
  `boiler_retour_temp` in géén repo-dashboard voorkomen (grep over `*.json` → 0). `setpoint_hotwater`
  is bewust NIET dood (14d-max 42,1 °C) en wordt niet geschrapt.
- [x] 3.5 De alertregel `ATAGBurnerCyclingExcessive` uit
  `modules/monitoring/prometheus/alerts/atag-alerts.yml` verwijderen; verifieer dat de overige
  ATAG-alerts intact zijn en de YAML geldig blijft (`grep -c ATAGBurnerCyclingExcessive` → 0).

## 4. Rendement uitsluitend op retourtemperatuur

- [x] 4.1 Uit `atag-boiler.json` het paneel "CV Temperatuur Delta (Efficiency Indicator)"
  (aanvoer − retour) verwijderen; verifieer dat de retour-timeseries ("CV Retourtemperatuur") en de
  "Condensatie Indicator"-gauge (beide op `cv_retour_temp`) blijven staan.
- [x] 4.2 Controleer dat geen enkel resterend rendements-/efficiency-paneel de aanvoer−retour-delta
  gebruikt, en dat `sensor.atag_one_boiler_retour_temp` nergens als bron staat (grep → 0).

## 5. Condensatie-bewaking op 55 °C retour

- [x] 5.1 Op het retour-paneel in `atag-boiler.json` ("CV Retourtemperatuur") een drempellijn op
  55 °C toevoegen (condensatiegrens); verifieer dat de lijn in Grafana zichtbaar is naast de reeks.
- [x] 5.2 Alertregel `ATAGReturnTempNotCondensing` toevoegen aan `atag-alerts.yml`:
  `homeassistant_sensor_temperature_celsius{entity="sensor.atag_one_cv_retour_temp"} > 55` met een
  `for:`-venster (bv. 30m), severity warning. Verifieer dat Prometheus de regel laadt en hij nu niet
  vuurt (retour-max 45,6 °C). Meest relevant ná de overstap naar room_regulation (ketelinstelling,
  buiten deze change).

## 6. Kalibratiepaneel buitensensor

- [x] 6.1 Nieuw timeseries-paneel toevoegen met expressie
  `homeassistant_sensor_temperature_celsius{entity="sensor.atag_one_kamer_temp"} - ignoring(entity,friendly_name) (homeassistant_sensor_temperature_celsius{entity="sensor.atag_one_buiten_temp"} > -40)`
  (kamer − buiten, met `> -40` op de buiten-term), titel die de kalibratie-bedoeling benoemt.
  Verifieer dat het paneel een reëel verschil toont (nu ~7–8 °C).

## 6b. Nuttige ATAG-sensoren tonen

- [x] 6b.1 Warmhoud-paneel toevoegen: timeseries van
  `homeassistant_sensor_temperature_celsius{entity="sensor.atag_one_boiler_retour_temp"}`, titel die
  "warmhoud/warmtewisselaar" benoemt (niet "retour"). Verifieer dat het zaagtandpatroon (~47–55 °C)
  zichtbaar is terwijl de CV-reeks laag blijft.
- [x] 6b.2 CV-aanvoersetpoint toevoegen aan de CV-temperatuur-timeseries (`atag-boiler.json`
  paneel 5 "Temperatuur Verloop"): nieuwe reeks
  `homeassistant_sensor_temperature_celsius{entity="sensor.atag_one_setpoint_hotwater"}`, legenda
  "CV-aanvoersetpoint". Verifieer dat de reeks tijdens het stoken ~40 °C toont naast aanvoer/retour.

## 7. (24u)-panelen periode-afhankelijk

- [x] 7.1 In `atag-thermal-dashboard.json` paneel 4 "Comfort Score (24u)" de `[24h:5m]`/`[24h]`-
  vensters vervangen door `[$__range:5m]`/`$__range`; verifieer dat de score herberekent bij een
  ander tijdbereik.
- [x] 7.2 Idem paneel 8 "Accuracy Score (24u)" en paneel 9 "Stability Score (24u)": `[24h:5m]` →
  `[$__range:5m]`.
- [x] 7.3 De misleidende "(24u)" uit de titels halen (panelen 1, 4, 8, 9) nu ze de tijdkiezer
  volgen; query van paneel 1 ongemoeid laten (hardcodeerde al niets). Verifieer dat
  `gas-consumption.json` paneel 7 "Afgelopen 24 uur" ongewijzigd `[24h]` houdt.

## 8. Uitrol en integratiecontrole

- [x] 8.1 `nixos-rebuild switch --flake .#malandro` draaien; verifieer dat Grafana de drie
  dashboards zonder parse-/query-fouten laadt (geen nieuwe errors in het grafana-journal voor deze
  dashboards) en Prometheus de alertregels zonder fout herlaadt.
- [x] 8.2 Visueel in Grafana controleren: gas-panelen tonen reële m³/h; buitentemp-min is
  plausibel; de vier dode panelen en het delta-rendementspaneel zijn weg; de 55 °C-drempellijn, het
  kalibratiepaneel, het warmhoud-paneel en de CV-setpoint-reeks staan er; de (24u)-panelen volgen een
  gewijzigd tijdbereik; de rendementsindicatie staat op `cv_retour_temp`.
- [x] 8.3 CHANGELOG bijwerken onder `## NEXT VERSION` (sectie aanmaken indien afwezig) met een
  gebruikersgerichte beschrijving van de dashboard-fixes.

## Workflow follow-up

- Overstap naar kamergeregeld stoken (room_regulation): ketel-/thermostaatinstelling, buiten deze
  change. Daarna is de 55 °C-retour-bewaking (groep 5) het meest zinvol.
- m³/graaddag-vergelijking: vervolg-change, zinvol zodra het stookseizoen loopt en de gasmeting
  (groep 1) staat. Overweeg dan een kook-basislast van de P1-meter af te trekken voor zuivere CV.
- Stooklijn / max aanvoertemperatuur verlagen: ketelinstelling (nu max aanvoer 60 °C, lage retour is
  een goed uitgangspunt), geen dashboardwerk — buiten deze change.
- Dode-sensor-panelen in Home Assistant (als die buiten de repo-Grafana bestaan) apart opruimen.
- Change archiveren nadat de implementatie is afgerond en geverifieerd.
