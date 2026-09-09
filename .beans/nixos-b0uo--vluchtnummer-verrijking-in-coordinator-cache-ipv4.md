---
# nixos-b0uo
title: Vluchtnummer-verrijking in coordinator (cache + IPv4, alleen getoonde toestellen)
status: completed
type: feature
priority: high
created_at: 2026-09-09T20:41:45Z
updated_at: 2026-09-09T20:59:55Z
parent: nixos-j7mc
---

De adsbdb-lookup inhaken in de coordinator, met caching en strakke rate-limit-discipline.

## Wat

- Na de bestaande adsb.lol-poll + `build_summary`: alléén voor `summary.nearest` en
  `summary.most_approaching` (de toestellen wier callsign als attribuut getoond wordt) het
  vluchtnummer opzoeken. NIET voor alle toestellen in de radius.
- **Cache** (dict `callsign → flight_number`) op de coordinator: callsign→vluchtnr is stabiel
  voor de hele vlucht, dus een cache-hit doet géén externe call. Overweeg een TTL of simpelweg
  legen bij herstart (in-memory volstaat).
- Negatieve resultaten ook cachen (callsign zonder route) om herhaald bevragen te voorkomen.

## Netwerk

- Client gebruikt `async_get_clientsession(hass, family=socket.AF_INET)` (IPv4-only), zelfde
  voorzorg als de adsb.lol-fix in `coordinator.py` (v0.1.2, IPv6-blackhole).

## Datastroom

- Verrijk zo dat `sensor.py` het vluchtnummer bij de juiste `EvaluatedAircraft` kan vinden.
  `Aircraft` is `frozen` → verrijking als aparte map/veld op de `MonitorSummary` of via de
  coordinator-cache die de sensor raadpleegt (ontwerpkeuze bij implementatie).

## Summary of Changes
Coordinator wires a second IPv4-only AdsbdbClient + per-callsign cache (negatives cached). Enrichment extracted to pure resolve_flight_numbers(candidates, cache, lookup) in adsbdb.py (HA-free, unit-tested), called after build_summary for nearest + most_approaching only (<=2/poll). Result stored on new MonitorSummary.flight_numbers (hex->number).
