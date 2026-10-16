## 1. Sessiestatus uitlezen (bean nixos-g3id)

- [x] 1.1 `session_status(tokens, token_mtime)` in `magister_server.py`: `auth_time` uit het JWT-payload (base64url + json), `last_refresh` uit token.json met mtime-fallback, `None` bij alles wat onleesbaar is. Verificatie: unit-tests in `magister_server_test.py` (geldig JWT, kapot JWT, ontbrekende claim, mtime-fallback)
- [x] 1.2 `_refresh_access_token` schrijft `last_refresh` mee in de atomaire write. Verificatie: unit-test met gemockte token-endpoint-respons, die controleert dat `last_refresh` in token.json staat en het refresh-token geroteerd is
- [x] 1.3 `MagisterServerClient.session_status()` die token.json + mtime leest en `session_status` aanroept. Verificatie: unit-test met een tijdelijk token.json

## 2. Footer (bean nixos-p507)

- [x] 2.1 `generate_index_html` neemt een optionele `session`-dict en toont "Ingelogd sinds", "Laatste refresh" en "Token-verloop: onbekend". Verificatie: unit-test die de footer controleert, zowel met bekende als met onbekende status
- [x] 2.2 De aanroepen in `main()` geven `client.session_status()` mee. Verificatie: code-review + tests groen

## 3. Prometheus-heartbeat (bean nixos-7yie)

- [x] 3.1 `write_heartbeat(session)` voegt `magister_auth_time_seconds` en `magister_last_refresh_seconds` toe, en laat ze weg als de waarde onbekend is. Verificatie: unit-test op het geschreven .prom-bestand (beide aanwezig / één weggelaten / bestaande heartbeat-metric altijd aanwezig)
- [x] 3.2 De aanroepen in `main()` geven de status mee; geen alertregel toegevoegd. Verificatie: grep op de alertregels laat geen nieuwe magister-alert zien

## 4. Opruimen en docs (beans nixos-27oj, nixos-60h0)

- [x] 4.1 `modules/magister/index.html` verwijderen na controle dat niets ernaar verwijst. Verificatie: `grep -rn "magister/index.html"` vindt alleen docs/runtime-paden
- [x] 4.2 `docs/magister.md`: sessieleeftijd via `auth_time`, het opaque refresh-token, de nieuwe footer en metrics, en een commando voor de sessieleeftijd. Verificatie: de doc noemt `magister_auth_time_seconds` en `last_refresh`

## 5. Integratie (bean nixos-cdus)

- [x] 5.1 `sudo nixos-rebuild switch --flake .#malandro` en herstart van magister-sync. Verificatie: de service draait, en `journalctl` toont geen tracebacks
- [x] 5.2 Live controle: `/var/lib/magister/index.html` toont "Ingelogd sinds 2026-09-01 …", en de heartbeat bevat beide nieuwe metrics, ook via `curl localhost:9090` (Prometheus-query). Verificatie: output van die commando's

## Workflow follow-up

- CHANGELOG bijwerken (als die er is), change archiveren, committen
