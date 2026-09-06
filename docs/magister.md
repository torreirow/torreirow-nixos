# Magister agenda-sync

Context-document voor de Magister-agenda-synchronisatie op **malandro**. Leest de agenda('s) van
de kinderen uit Magister en publiceert ze als iCal-feeds (Google Calendar) op
`https://agenda.toorren.net/`.

> **Kern in één zin:** sinds 2026-09-01 draait de auth op de **OAuth refresh-token flow** van de
> mobiele Magister-app (`M6LOAPP`) met stille access-token-refresh — géén browser/cookie-scrape meer,
> dus geen ~10-uurs sessie-cliff.

## Architectuur

```
token.json (refresh_token, roteert)
    │  grant_type=refresh_token  →  accounts.magister.net/connect/token
    ▼
access_token (Bearer, 1u)  →  groevenbeek.magister.net/api/...  →  afspraken  →  *.ics + index.html
```

- **Auth:** OAuth2 authorization-code + PKCE + `offline_access`, mobiele-app-client. De server
  gebruikt alléén de **refresh-token flow**: access-token verlopen? → verversen. Het refresh-token
  **roteert** bij elk gebruik en wordt atomair teruggeschreven.
- **Data:** directe REST-calls met `Authorization: Bearer <access_token>`. Geen Playwright/Chromium.
- **Publicatie:** nginx serveert `/var/lib/magister/*.ics` op `agenda.toorren.net` (feeds publiek voor
  Google Calendar; de index-pagina zit achter Authelia).

## Bestanden

| Pad | Rol |
|--------------------------------------------|--------------------------------------------------------|
| `modules/magister/magister_server.py` | De service (auth, fetch, iCal-export, keep-alive-loop) |
| `modules/magister/magister-service.nix` | NixOS-module (systemd-unit, nginx, user/group) |
| `modules/magister/verify_pkce.py` | **Bootstrap/re-login** op de laptop (passkey) → refresh-token |
| `modules/magister/refresh_test.py` | Diagnose: refresh + rotatie + API-acceptatie testen |
| `modules/magister/probe_api.py` | Diagnose: JWT-claims + endpoint-ontdekking |
| `modules/magister/README.md` | ⚠️ Legacy (beschrijft de oude cookie-flow) |
| `/var/lib/magister/token.json` | **State** (0600): `{refresh_token, access_token, access_expires}` |
| `/var/lib/magister/magister_<naam>.ics` | Gegenereerde agenda-feeds (owner `magister:nginx`) |
| `/var/lib/magister/index.html` | Overzichtspagina |
| `/var/log/magister/magister.log` | Logs (ook via `journalctl -u magister-sync`) |

`token.json` en `magister_pkce_result.json` staan in `.gitignore` (secrets).

## OAuth-parameters (mobiele client)

```
authority     https://accounts.magister.net
authorize     /connect/authorize
token         /connect/token
client_id     M6LOAPP
redirect_uri  m6loapp://oauth2redirect/        (custom scheme; code in fragment van 302 Location)
response_type code id_token                     (hybrid)
scope         openid profile offline_access
acr_values    tenant:groevenbeek.magister.net
auth method   none (public client, PKCE S256)
prompt        select_account
```

Groevenbeek federeert naar **Microsoft-SSO** (username+wachtwoord+MFA of **passkey**). Daarom moet de
**eerste** login interactief (passkey in een echte browser via `verify_pkce.py`). Daarna vernieuwt de
server stil, zónder MFA.

## API-endpoints

| Call | Doel |
|-------------------------------------------------|-------------------------------------|
| `GET /api/account` | Account → `Persoon.Id` (ouder = 32750) |
| `GET /api/personen/<accountId>/kinderen` | Kinderen (Boaz: Id 41801, Stamnr 18370) |
| `GET /api/personen/<kindId>/afspraken?van=&tot=`| Afspraken (window: maandag t/m +21 dagen) |
| `GET /api/versie` | Publiek (geen token), handig als up-check |

Access-token-audience is `https://accounts.magister.net/resources` — dat wordt door de tenant-API
geaccepteerd (dat is de normale Magister-IdentityServer-resource).

## iCal-export — statuscodes & InfoType

De export spiegelt Magister-velden (zie ook geheugen `magister-status-codes`):

- **Status 5 (verplaatst):** overslaan (leeg "spook" op het oude lesuur; de echte les draait als
  Status 1 op zijn nieuwe uur).
- **Status 3 (uitgevallen):** `[UITGEVALLEN]`-label + `TRANSP:TRANSPARENT` (blokkeert je tijd niet).
- **Status 2 (gewijzigd):** `[GEWIJZIGD]`-label.
- **InfoType:** 📚 huiswerk, 📝 toets/SO/mondeling/tentamen, ℹ️ info.
- Tijden: Magister levert UTC (`...Z`); wordt genormaliseerd zodat Google Calendar niet 1-2u verschuift.

## Cadans & footprint (opvallen vermijden)

Om niet als bot op te vallen in Magisters logs:

- **Keep-alive:** ~30 min (`KEEP_ALIVE_INTERVAL`) met ±5 min **jitter** (`KEEP_ALIVE_JITTER`),
  alléén tussen **07:00–22:00** (`WINDOW_START_HOUR`/`WINDOW_END_HOUR`). 's Nachts stil; bij
  service-start altijd één directe fetch, daarna volgt het venster.
- **User-Agent:** alle token- en API-calls sturen `MAGISTER_UA` (app-achtig, `M6LOAPP`) i.p.v.
  het opvallende `Python-urllib/x.y`.
- De **max** keep-alive-interval wordt begrensd door de (onbekende) refresh-token idle-window;
  de access-token (1 u) verversen we sowieso elke keer. ~30 min zit daar ruim binnen.

## Fout-afhandeling

- **`invalid_grant` bij refresh** (refresh-token dood — bv. wachtwoordwijziging/intrekken): service
  stopt met **exit 1** + e-mail naar `wvdtoorren@gmail.com`. `RestartPreventExitStatus=1` → géén retry;
  handmatige re-login nodig (zie runbook).
- **5xx / netwerk / Magister-onderhoud** ("Magister tijdelijk niet beschikbaar"): **niet** fataal —
  `test_session()` beschouwt de sessie als geldig zolang refresh lukt. Even later vanzelf goed.
- Prometheus-heartbeat: `/var/lib/prometheus-node-exporter-textfiles/magister_heartbeat.prom`.

## Re-login runbook (alleen bij `invalid_grant` — verwacht: maanden)

1. **lobos:** `python3 modules/magister/verify_pkce.py` → login met **passkey** → `magister_pkce_result.json`.
2. `scp modules/magister/magister_pkce_result.json malandro:/tmp/magister_seed.json`.
   ⚠️ Draai daarna **geen** `refresh_test.py`/`verify_pkce.py` meer op lobos — die roteren het token en
   maken de seed ongeldig.
3. **malandro:**
   ```bash
   sudo python3 -c "import json;d=json.load(open('/tmp/magister_seed.json'));json.dump({'refresh_token':d['refresh_token']},open('/var/lib/magister/token.json','w'))"
   sudo chown magister:magister /var/lib/magister/token.json && sudo chmod 600 /var/lib/magister/token.json
   sudo shred -u /tmp/magister_seed.json
   sudo systemctl restart magister-sync.service
   ```

## Handige commando's

```bash
# Status & logs
systemctl status magister-sync.service
journalctl -u magister-sync.service -f

# Handmatig één sync-run (service herstart doet ook een directe fetch)
sudo systemctl restart magister-sync.service

# Token-state bekijken (geen waarden lekken)
sudo python3 -c "import json,time;d=json.load(open('/var/lib/magister/token.json'));print('keys',list(d.keys()),'access nog %.0f min'%((d.get('access_expires',0)-time.time())/60))"

# Diagnose op lobos (met token in magister_pkce_result.json)
python3 modules/magister/refresh_test.py   # refresh + rotatie + /api/account
python3 modules/magister/probe_api.py      # JWT-claims + endpoint-scan

# Rebuild na wijziging
sudo nixos-rebuild switch --flake .#malandro
```

## Bekende (onschadelijke) restpunten

- postStart `systemctl reload nginx` faalt met "Access denied" (polkit). Onschadelijk: nginx serveert
  de `.ics` direct van schijf; een reload is niet nodig voor gewijzigde bestanden.
- Cosmetische `datetime.utcnow()` DeprecationWarning in `export_to_ical` (behouden code).

## Historie

Vóór 2026-09-01 gebruikte de service een via Playwright gescrapete **cookie-sessie**
(`magister_session.json`, implicit flow). Die had een absolute SSO-cap van ~10 u die keep-alive niet
kon oprekken → periodiek "Failed to fetch" (302→login, CORS) en handmatig opnieuw inloggen. Vervangen
door de refresh-token flow hierboven (commit `04c2c74`, geheugen `magister-refresh-token-m6loapp`).
