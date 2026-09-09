---
# nixos-pwoz
title: flight_number-attribuut op de sensoren
status: completed
type: task
priority: normal
created_at: 2026-09-09T20:41:45Z
updated_at: 2026-09-09T20:59:55Z
parent: nixos-j7mc
---

Het `flight_number`-attribuut toevoegen aan de sensor-attributen.

## Wat

- In `sensor.py::_aircraft_attributes` (of per-sensor `extra_state_attributes`) een sleutel
  `flight_number` toevoegen, gevuld uit de coordinator-verrijking (nixos-parent feature).
- `null` als het vluchtnummer onbekend is (adsbdb "not found" of nog niet opgezocht).
- `callsign` blijft ongewijzigd naast `flight_number` staan.

## Raakt

- `sensor.NearestAircraftSensor` en `sensor.ApproachingAircraftSensor` (die tonen de attrs).

## Summary of Changes
flight_number attribute added to nearest/approaching sensors and approaching binary sensor, read from coordinator.data.flight_numbers by hex; null when unknown. callsign retained.
