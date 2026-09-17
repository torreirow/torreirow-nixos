---
# nixos-cl5o
title: Tests + versie-bump (v0.3.0) + docs/CHANGELOG
status: completed
type: task
priority: normal
created_at: 2026-09-09T20:41:45Z
updated_at: 2026-09-09T20:59:55Z
parent: nixos-j7mc
---

Tests, versie-bump en documentatie afronden.

## Tests (pure logic, pytest — geen HA nodig)

- adsbdb-parse: geldige response → "KL1673"; 404/lege flightroute → `None`; invalide JSON → `None`.
- Cache-gedrag: tweede lookup van dezelfde callsign doet géén tweede call; negatief resultaat
  wordt gecached.
- Eenheid-conversie: ft→m en kts→km/h afronding (bv. 34000 ft → 10363 m, 452 kts → 837 km/h),
  `None`-invoer → `None`.

## Release

- `manifest.json` version-bump (v0.2.0 → v0.3.0) + git-tag.
- CHANGELOG/README: nieuw `flight_number`-attribuut, gewijzigde eenheden (meter/km/h),
  adsbdb.com als databron vermelden.
- Lint schoon (pyflakes + pycodestyle) en imports verifiëren tegen de draaiende container
  (`sudo docker exec homeassistant python -c "..."`).

## Summary of Changes
Added tests/test_adsbdb.py + tests/test_units.py (suite 49->64, all pass). manifest 0.2.0->0.3.0, new CHANGELOG.md, README updated. HA-runtime import check of all modules in live container: OK.
