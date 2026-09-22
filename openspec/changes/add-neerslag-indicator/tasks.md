## 1. Buienradar-integratie (HA-runtime, malandro)

- [x] 1.1 Buienradar core-integratie toevoegen met `timeframe: 120` (config-flow of `.storage/core.config_entries`; backup van dat bestand maken vóór edit) en verifiëren dat de drie sensoren bestaan: `sensor.*_precipitation`, `sensor.*_precipitation_forecast_average`, `sensor.*_precipitation_forecast_total`
- [x] 1.2 De exacte entity-id's noteren en verifiëren dat `precipitation` (mm/h) en `precipitation_forecast_total` (mm) een geldige numerieke waarde hebben in Developer Tools → States

## 2. Dauwpunt-heuristiek (HA-runtime, configuration.yaml)

- [x] 2.1 Backup van `configuration.yaml` maken (`*.bak-claude-<datum>`) en template-sensor `sensor.buiten_dauwpunt` toevoegen (Magnus a=17.625, b=243.04; bron `sensor.buitentempsensor_temperature` + `sensor.buitentempsensor_humidity`; `device_class: temperature`; `availability` zodat de sensor onbeschikbaar is als een bron ontbreekt)
- [x] 2.2 Template-sensor `sensor.buiten_dauwpunt_spread` (= buitentemp − dauwpunt, `device_class: temperature`) toevoegen; HA-config valideren met `hass --script check_config` en verifiëren dat beide sensoren na reload een plausibele waarde tonen (dauwpunt ≤ temp)

## 3. Samengestelde neerslag-indicator (HA-runtime, configuration.yaml)

- [x] 3.1 Template-sensor `sensor.neerslag_indicator` toevoegen met de vier toestanden in volgorde `Regent` → `Bui op komst` → `Verzadigd` → `Droog` (radar leidend; `Verzadigd` alleen wanneer de radar droog is én spread ≤ drempel én RV ≥ drempel). Conservatieve startdrempels: regent > 0.1 mm/h, bui op komst totaal > 0.2 mm, verzadigd spread ≤ 1 °C & RV ≥ 95 %
- [x] 3.2 HA herladen en verifiëren dat `sensor.neerslag_indicator` een van de vier toestanden aanneemt en logisch reageert op de actuele radar/vocht-waarden

## 4. Prometheus-export bevestigen (geen wijziging)

- [x] 4.1 Bevestigen dat de neerslag- en dauwpuntsensoren automatisch in Prometheus verschijnen (geen glob-wijziging): query `homeassistant_sensor_precipitation_intensity_mm_per_h`, `homeassistant_sensor_precipitation_mm` en `homeassistant_sensor_temperature_celsius{entity="sensor.buiten_dauwpunt"}` op `http://127.0.0.1:9090` en controleer dat er series terugkomen
- [x] 4.2 Vaststellen welk `entity`-label hoort bij `precipitation` versus `precipitation_forecast_average` (delen dezelfde metric) en dit label noteren voor de dashboard-queries

## 5. Grafana-dashboard uitbreiden (deze repo)

- [x] 5.1 In `modules/monitoring/grafana/dashboards/torreiro/temperature-humidity.json` een rij "Neerslag" toevoegen met een stat "Neerslag nu" (mm/h, `homeassistant_sensor_precipitation_intensity_mm_per_h` gefilterd op het huidige-neerslag-entity-label) en een stat "Verwacht komende 2u" (mm, `homeassistant_sensor_precipitation_mm`) met kleur-drempels
- [x] 5.2 Een timeseries-paneel "Neerslag verloop" (mm/h) toevoegen aan dezelfde rij
- [x] 5.3 `sensor.buiten_dauwpunt` (en/of `_spread`) als extra lijn(en) toevoegen aan het bestaande temperatuur- of luchtvochtigheid-timeseries-paneel
- [x] 5.4 Valideren dat het JSON geldig is (`python3 -c "import json,glob; json.load(open('modules/monitoring/grafana/dashboards/torreiro/temperature-humidity.json'))"`) en dat panelen unieke `id`'s houden
- [x] 5.5 Dashboard live controleren na Grafana-provisioning-reload: de rij "Neerslag" en de dauwpuntlijn tonen data (geen "No data")

## 6. Afstellen en documenteren

- [ ] 6.1 Na enkele dagen data de drempels in `sensor.neerslag_indicator` (en de stat-kleurdrempels) empirisch bijstellen aan de hand van waargenomen regen/mist-situaties
- [x] 6.2 Backups en de doorgevoerde HA-runtime-wijzigingen kort documenteren in CLAUDE.md (welke sensoren, welke bestanden, welke backup-namen)
