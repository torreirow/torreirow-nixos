## Why

De overzichtspagina op `agenda.toorren.net` toont alleen "Laatste update:". Of de Magister-sessie
gezond is en hoe oud die is, is nergens te zien. Het refresh-token is een opaque reference-token
zonder verloopdatum. Het access-token bevat wel de claim `auth_time`, het moment van de
passkey-login. Die claim gaat bij elke refresh mee. Gemeten op 2026-10-15: login op 2026-09-01
09:49, dus de sessie leeft al 44 dagen. Die informatie is er, maar niemand ziet haar.

## What Changes

- **Footer van de index** krijgt drie regels onder "Laatste update:":
  - "Ingelogd sinds:" met datum, tijd en de leeftijd in dagen;
  - "Laatste refresh:" met het tijdstip van de laatste geslaagde token-refresh;
  - "Token-verloop: onbekend (Magister geeft dit niet prijs)".
- **Laatste refresh vastleggen**: `_refresh_access_token` schrijft een veld `last_refresh` in
  `token.json`, atomair samen met de nieuwe tokens.
- **Prometheus-heartbeat** krijgt de metrics `magister_auth_time_seconds` en
  `magister_last_refresh_seconds`. Er komt **geen** alertregel bij, want de levensduurgrens is
  onbekend.
- **Opruimen**: de verouderde `modules/magister/index.html` in de repo verdwijnt, en
  `docs/magister.md` wordt bijgewerkt.

## Capabilities

### New Capabilities
- `magister-session-status`: de leeftijd en de laatste refresh van de Magister-sessie zichtbaar
  maken in de index-footer en als Prometheus-metrics, zonder een verloopdatum te suggereren.

### Modified Capabilities
<!-- Er bestaat nog geen Magister-spec; niets gewijzigd. -->

## Impact

- `modules/magister/magister_server.py`: een nieuwe helper voor de sessiestatus, plus aanpassingen
  in `_refresh_access_token`, `generate_index_html` en `write_heartbeat`.
- `/var/lib/magister/token.json` krijgt een extra veld `last_refresh`. Dat is backwards-compatible:
  ontbreekt het veld, dan wordt de mtime van het bestand gebruikt.
- `magister_heartbeat.prom` krijgt twee extra series. Bestaande alerts blijven ongewijzigd.
- Nieuw: `modules/magister/magister_server_test.py` (unit-tests).
- Verwijderd: `modules/magister/index.html`.
- `docs/magister.md`.
