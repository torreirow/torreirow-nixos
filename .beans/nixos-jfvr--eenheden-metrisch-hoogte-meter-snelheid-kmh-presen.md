---
# nixos-jfvr
title: 'Eenheden metrisch: hoogte → meter, snelheid → km/h (presentatielaag)'
status: completed
type: task
priority: normal
created_at: 2026-09-09T20:41:45Z
updated_at: 2026-09-09T20:59:55Z
parent: nixos-j7mc
---

De `altitude`- en `speed`-attributen omzetten naar meters en km/h in de presentatielaag.

## Wat

- In `sensor.py::_aircraft_attributes`:
  - `altitude` = `round(a.altitude_ft * FEET_TO_METERS)` (meter i.p.v. voet)
  - `speed`    = `round(a.speed_knots * KM_PER_NAUTICAL_MILE)` (km/h i.p.v. knopen)
- Eenheid **vervangen**, niet naast elkaar (bevestigd door user).
- `None`-veilig: als `altitude_ft`/`speed_knots` `None` is → attribuut `None`.

## Belangrijk

- Conversie UITSLUITEND hier (presentatie). NIET in `Aircraft` of `processing.py`: de filters
  `min/max_altitude_ft` en `min_speed_kts` en de config-flow blijven in ft/kts werken.
- Constanten `FEET_TO_METERS` (0.3048) en `KM_PER_NAUTICAL_MILE` (1.852) bestaan al in `const.py`.

## Summary of Changes
New pure units.py (feet_to_meters, knots_to_kmh) kept out of Aircraft/processing. sensor.py + binary_sensor.py report altitude in metres and speed in km/h. Internal min/max_altitude_ft + min_speed_kts filters and config flow unchanged (ft/kts). Covered by tests/test_units.py.
