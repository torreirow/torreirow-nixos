---
# nixos-j7mc
title: 'Aircraft-monitor: vluchtnummer (IATA) + metrische eenheden (km/h, meter)'
status: completed
type: epic
priority: normal
created_at: 2026-09-09T20:40:51Z
updated_at: 2026-09-09T21:00:03Z
---

Thematische container. De HA custom integration `torreirow/home-assistant-aircraft-monitor`
(aparte repo, zie memory [[aircraft-monitor-integration]]) uitbreiden zodat de getoonde
vliegtuigen een **commercieel vluchtnummer** krijgen en de eenheden **metrisch** zijn.

## Waarom

Bij een gedetecteerd toestel wil je in één oogopslag "KL1673" zien i.p.v. de kale
ADS-B-callsign, en snelheid/hoogte in km/h en meters i.p.v. knopen en voet.

## Besluiten (uit /opsx:explore)

- **Vluchtnummer = IATA** ("KL1673"), afgeleid van de ADS-B-callsign ("KLM1673") via een
  externe lookup. ADS-B zelf bevat GEEN commercieel vluchtnummer; de `callsign` (veld `flight`)
  is iets anders. Enkel het vluchtnummer gewenst — géén route/airline/origin-destination.
- **Bron = adsbdb.com** (`GET https://api.adsbdb.com/v0/callsign/{callsign}` →
  `response.flightroute.callsign_iata`). Gratis, geen API-key.
- **Rate-limit-discipline** (les uit adsb.lol v0.1.3): alléén de getoonde toestellen opzoeken
  (`nearest` + `most_approaching`, dus ~2 per poll), resultaat **cachen** per callsign
  (callsign→vluchtnr is stabiel voor de hele vlucht), "not found" → attribuut `null`, geen crash.
- **IPv4-only** voor adsbdb (zelfde IPv6-blackhole-voorzorg als adsb.lol,
  `async_get_clientsession(hass, family=socket.AF_INET)`).
- **Eenheden = vervangen (niet naast elkaar)** en uitsluitend in de presentatielaag
  (`sensor.py::_aircraft_attributes`): `altitude` = meter (ft × 0.3048), `speed` = km/h
  (kts × 1.852). De constanten `FEET_TO_METERS` / `KM_PER_NAUTICAL_MILE` bestaan al in `const.py`.
- **Interne filters blijven in ft/kts** (`min/max_altitude_ft`, `min_speed_kts`, config-flow) —
  conversie NIET in `Aircraft`/`processing.py` doen, anders breken de filters.

## Resultaat (sensor-attributen)

```
callsign:       "KLM1673"   (blijft, uit ADS-B)
flight_number:  "KL1673"    NIEUW (adsbdb, null bij onbekend)
altitude:        10363      NU IN METERS  (was 34000 ft)
speed:           837        NU IN KM/H    (was 452 kts)
```

## Scope-noot

Code leeft in de aparte repo `home-assistant-aircraft-monitor`; distributie via HACS
(HA draait als Docker-container, geen HAOS). Waarschijnlijk versie-bump naar v0.3.0.

## Summary of Changes
Implemented in repo home-assistant-aircraft-monitor (v0.3.0). All 5 child beans done.
- flight_number (IATA) via adsbdb.com, cached per callsign, IPv4-only, best-effort, nearest+approaching only.
- altitude in metres, speed in km/h on sensors + binary sensor; internal ft/kts filters untouched.
- New modules adsbdb.py, units.py; new MonitorSummary.flight_numbers field.
- Tests 49->64 (test_adsbdb.py, test_units.py), all pass. README/CHANGELOG/manifest updated. HA-container import check OK.
No separate OpenSpec change created: the code repo has no OpenSpec configured and the beans fully captured the design (decision recorded here).
