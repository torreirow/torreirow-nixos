---
# nixos-pulg
title: 'adsbdb.com client: callsign → IATA-vluchtnummer'
status: completed
type: feature
priority: high
created_at: 2026-09-09T20:41:45Z
updated_at: 2026-09-09T20:59:55Z
parent: nixos-j7mc
---

Thin async client voor adsbdb.com die een ADS-B-callsign vertaalt naar het IATA-vluchtnummer.

## Wat

- Nieuwe module (bv. `adsbdb.py`) naast `api.py`, injecteerbaar met een mock-session zodat de
  parse-logica zonder netwerk testbaar is (zelfde stijl als `AdsbLolClient`).
- `GET https://api.adsbdb.com/v0/callsign/{callsign}` → parse
  `response.flightroute.callsign_iata` → vluchtnummer (bv. "KL1673").
- Callsign wordt getrimd/upper-cased voor de query; lege/None callsign → geen call, return `None`.

## Foutafhandeling

- HTTP 404 / "unknown callsign" → `None` (geen exception; veel toestellen hebben geen route).
- Timeout / ClientError / invalide JSON → gelogd op debug, return `None` (best-effort verrijking,
  mag de poll nooit laten falen).
- Eigen timeout-constante (hergebruik `DEFAULT_API_TIMEOUT` of aparte).

## Constanten

- `ADSBDB_BASE_URL = "https://api.adsbdb.com/v0"` in `const.py`.

## Summary of Changes
Added adsbdb.py: AdsbdbClient (thin, injectable) + parse_flight_number (pure) resolving callsign->IATA via api.adsbdb.com/v0/callsign. Best-effort: 404/timeout/ClientError/invalid-JSON/blank-callsign -> None, never raises. Added ADSBDB_BASE_URL to const.py. Covered by tests/test_adsbdb.py.
