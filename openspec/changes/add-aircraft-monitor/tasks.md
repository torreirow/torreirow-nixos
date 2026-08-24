## 1. Repository & scaffolding

- [x] 1.1 Bevestig `gh auth status` (account `torreirow`) en maak publieke repo `torreirow/home-assistant-aircraft-monitor` aan, lokaal gecloned
- [x] 1.2 Voeg `.gitignore` (Python), `LICENSE` (MIT) en een placeholder `README.md` toe
- [x] 1.3 Maak de mappenstructuur `custom_components/aircraft_monitor/`, `custom_components/aircraft_monitor/translations/`, `tests/`

## 2. Constants & manifest

- [x] 2.1 `const.py`: DOMAIN, event-naam `aircraft_monitor.aircraft_approaching`, config-keys, en alle defaults (lat 52.2946, lon 5.5989, radius 20 km, alert 250 m, prediction 180 s, poll 10 s, min alt 0 ft, max alt 15000 ft, min speed 25 kt) + hysterese-factor/cooldown/`seen_pos`-drempel
- [x] 2.2 `manifest.json`: domain, name, `config_flow: true`, `iot_class: cloud_polling`, `version`, `documentation`/`issue_tracker`, geen extra runtime-requirements
- [x] 2.3 `strings.json` + `translations/en.json` voor config-flow en options-flow labels

## 3. Geo-module (pure logica)

- [x] 3.1 `geo.py`: equirectangular projectie lat/lon → lokale ENU-meters rond een target
- [x] 3.2 `geo.py`: `predict_closest_approach(...)` met analytische `t*`-oplossing, clamp naar `[0, prediction_time]`, retour `ClosestApproach(current_distance_m, closest_distance_m, time_to_closest_approach_s, predicted_lat, predicted_lon)` en een "moving toward"-indicatie
- [x] 3.3 `geo.py`: veilige afhandeling van ontbrekende track/snelheid en snelheid ≈ 0 (geen deel-door-nul), knots→m/s (`0.514444`)

## 4. API-client

- [x] 4.1 `api.py`: async client op HA's `aiohttp`-sessie, endpoint-URL met radius km→nm (`/1.852`), redelijke timeout, geen blocking calls
- [x] 4.2 `api.py`: normaliseer ruwe records naar een `dataclass` met veilige coercions (`flight.strip()`, `alt_baro="ground"→0`, ontbrekend/`null`→`None`, numerieke velden gevalideerd)
- [x] 4.3 `api.py`: vertaal connection/timeout/HTTP/JSON-fouten naar één integratie-eigen exceptietype; log geen volledige JSON op INFO

## 5. Coordinator (data + state-machine)

- [x] 5.1 `coordinator.py`: `DataUpdateCoordinator` met `update_interval = poll_interval`, roept API-client aan, zet fouten om in `UpdateFailed`
- [x] 5.2 `coordinator.py`: lokale filtering op min/max hoogte, min snelheid en stale `seen_pos`
- [x] 5.3 `coordinator.py`: per relevant vliegtuig closest approach berekenen; samenvatting produceren (count, nearest, most-approaching)
- [x] 5.4 `coordinator.py`: approaching-bepaling (closest ≤ alert_distance AND eta ≤ prediction_time AND moving toward)
- [x] 5.5 `coordinator.py`: flank-getriggerde dedup-state-machine per `hex` met hysterese + cooldown + purge van stale hexes
- [x] 5.6 `coordinator.py`: vuur `aircraft_monitor.aircraft_approaching` met vereiste eventdata op de NOT→APPROACHING-flank

## 6. Integratie-setup & entities

- [x] 6.1 `__init__.py`: `async_setup_entry` / `async_unload_entry`, coordinator per entry aanmaken, platforms forwarden; options-update listener
- [x] 6.2 `sensor.py`: aircraft-count, nearest-aircraft (afstand + attributen), approaching-aircraft (afstand/ETA + attributen), unieke ids per entry, device per locatie
- [x] 6.3 `binary_sensor.py`: aircraft-approaching binary_sensor met de vereiste attributen
- [x] 6.4 Device-info per config-entry zodat meerdere locaties naast elkaar bestaan

## 7. Config-flow & options-flow

- [x] 7.1 `config_flow.py`: config-flow voor naam + latitude/longitude met validatie (-90..90 / -180..180)
- [x] 7.2 `config_flow.py`: options-flow voor radius/alert/prediction/poll/min-max-hoogte/min-snelheid met validatie (radius>0, alert>0, prediction>0, poll≥5, min_alt≤max_alt, min_speed≥0)
- [x] 7.3 Bevestig dat meerdere entries mogelijk zijn en dat niets hardcoded is (alle waarden uit config/options)

## 8. Tests (pure logic eerst)

- [x] 8.1 `tests/test_geo.py`: recht-op-af, van-af, parallel, recht-over, koers 359→0, lage snelheid, ontbrekende track, ontbrekende snelheid, buiten prediction-venster, binnen 250 m
- [x] 8.2 `tests/test_api.py`: mock HTTP — geldige response, lege response, ontbrekende velden, `alt_baro="ground"`, ongeldige JSON, timeout/HTTP-fout (geen internet nodig)
- [x] 8.3 `tests/test_coordinator.py`: filtering + approaching-bepaling + duplicate-prevention (één event, geen herhaling, opnieuw naderen na verlaten van de zone)
- [x] 8.4 `tests/__init__.py` + pytest-config; hele suite groen zonder internet

## 9. HACS, CI & documentatie

- [x] 9.1 `hacs.json` met correcte metadata (naam, categorie Integration)
- [x] 9.2 GitHub Actions: `hassfest`-validatie, `hacs/action` validate, en `pytest` op de pure-logic tests
- [x] 9.3 Uitgebreide `README.md`: HACS-installatie (Docker-HA, geen HAOS), handmatige installatie, configuratie, entities, automation-voorbeeld (moderne HA-YAML), troubleshooting, API-info, privacy/gegevensgebruik
- [x] 9.4 Valideer JSON (`manifest.json`/`hacs.json`/`en.json`), YAML in de README, en Python-lint/format

## 10. Verificatie & publicatie

- [x] 10.1 Draai `python -m pytest` lokaal → alles groen; controleer git-status
- [x] 10.2 Eerste commit "Initial implementation of ADS-B aircraft monitor", tag `v0.1.0`, push naar `github.com/torreirow/home-assistant-aircraft-monitor`
- [x] 10.3 Geïnstalleerd via HACS op de Docker-HA (2026.7.2); na fix v0.1.1 (DeviceInfo-import) laadt de entry en zijn de 4 entities geregistreerd
