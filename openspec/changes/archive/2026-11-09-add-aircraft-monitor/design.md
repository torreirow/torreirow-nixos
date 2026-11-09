## Context

Zie `proposal.md` — Why. De integratie leeft in een **aparte publieke repo**
(`torreirow/home-assistant-aircraft-monitor`), niet in deze nixos-repo. Twee harde omgevings-
constraints sturen het ontwerp:

- **HA draait als kale Docker-container** (`ghcr.io/home-assistant/home-assistant:stable`, met
  `/var/lib/homeassistant:/config` gemount) — **geen HAOS/Supervisor**. Daardoor: geen add-on-repo,
  en distributie loopt via **HACS custom repository** (HACS is al aanwezig). Een NixOS-module is niet
  nodig en is bewust geschrapt.
- **ADSB.lol v2 API** is geverifieerd tijdens explore: response = `{ ac: [...], now, total, ... }`.
  Bevestigde per-record velden en gotchas: `flight` heeft trailing spaces (`.strip()`), `alt_baro`
  kan de string `"ground"` zijn, `seen_pos` geeft de leeftijd van de positie (stale posities negeren),
  en de API geeft gratis `dst`/`dir` (afstand/richting vanaf querypunt) als cross-check mee.

## Goals / Non-Goals

**Goals:**
- Zuivere scheiding tussen **pure, testbare logica** (`geo.py`, filtering, dedup-beslissing) en
  **HA-glue** (coordinator, entities, config-flow), zodat de kern zonder HA-testharness te testen is.
- **Multi-entry vanaf de fundering**: 1 ConfigEntry = 1 locatie = 1 DataUpdateCoordinator = 1 device.
- Robuustheid boven volledigheid: ontbrekende velden en API-storingen mogen nooit crashen.
- HACS-ready met CI die manifest/hacs.json valideert en de pure-logic tests draait.

**Non-Goals:**
- Geen NixOS-module of systemd-service (HA blijft eigenaar van lifecycle) — expliciet buiten scope.
- Geen volledige HA-testharness in de eerste iteratie (`config_flow`/`sensor`-tests met
  `pytest-homeassistant-custom-component` zijn een gemarkeerde follow-up).
- Geen map-/Lovelace-kaart, geen historische opslag/trending, geen meerdere API-providers.
- Geen daadwerkelijke gelijktijdige implementatie van Home/Camping/Werk — alleen de architectuur moet
  het aankunnen.

## Decisions

### D1 — Closest approach: analytische vector-oplossing op lokaal ENU-vlak
Projecteer vliegtuig en target naar lokale meters (equirectangular rond de target als oorsprong).
Positie `p₀=(x₀,y₀)`, snelheid `v = v_ms·(sin(track), cos(track))` (track = graden CW vanaf noord →
oost=sin, noord=cos). Minimale afstand tot oorsprong: `t* = -(p₀·v)/(v·v)`, geclamped naar
`[0, prediction_time]`; `closest = |p₀ + t_clamped·v|`; "naar toe" ⇔ `p₀·v < 0`.
- *Waarom:* gesloten vorm (geen iteratie), numeriek stabiel, en sin/cos lost 359°→0° vanzelf op.
- *Alternatieven:* iteratief samplen langs de baan (traag, minder precies); haversine per stap
  (onnodig zwaar op deze schaal). Verworpen.
- *Let op:* `closest` is het minimum over het **venster** `[0, T]`, niet de oneindige lijn — de
  spec-scenario's (parallel → loodrecht) gelden mits de loodrechte voet binnen `T` valt; testwaarden
  daarop afstemmen.

### D2 — Één coordinator per config-entry, entities zijn passieve consumenten
`DataUpdateCoordinator` met `update_interval = poll_interval`. Entities lezen alleen uit
`coordinator.data`; ze pollen zelf niet. De coordinator produceert een gestructureerd resultaat
(lijst van verrijkte vliegtuigen + samenvatting: count, nearest, most-approaching).
- *Waarom:* HA-idiomatisch, één API-call per locatie per interval, entities blijven triviaal.
- *Alternatief:* per-entity polling — verworpen (API-hammering, race conditions).

### D3 — Dedup als flank-getriggerde state-machine in de coordinator, key = `hex`
State per `hex`: `{approaching: bool, last_seen, last_event_ts}`. Event vuurt op de flank
NOT→APPROACHING. Herarm pas wanneer `closest > alert_distance · hysterese_factor` (bijv. 1.3) of
wanneer de `hex` gedurende een cooldown niet meer approaching/gezien is. Stale `hex` (N intervallen
niet gezien) wordt gepurged.
- *Waarom:* voorkomt event-spam elke 10 s én voorkomt geflapper rond de grens; herhaalde passage
  (het 15:10-voorbeeld) vuurt weer.
- *Alternatief:* simpele "was_approaching" boolean zonder hysterese — verworpen (flappert op de grens).
- *Opslag:* in-memory in de coordinator (geen globale mutable state; per-entry geïsoleerd). Bewust
  niet persistent over HA-herstart — een herstart mag opnieuw armen.

### D4 — Config-flow (identiteit) + options-flow (tunables)
Config-flow zet naam + latitude/longitude (de identiteit van een locatie); options-flow beheert
radius, alert_distance, prediction_time, poll_interval, min/max hoogte, min snelheid met validatie via
voluptuous. Defaults zijn constants in `const.py`, nooit hardcoded in de logica.
- *Waarom:* tunables bijstellen zonder de entry opnieuw toe te voegen; locatie-identiteit blijft stabiel.
- *Alternatief:* alles in config-flow — werkt, maar dwingt verwijderen/opnieuw toevoegen bij tunen.

### D5 — API-client als dunne, injecteerbare async-laag
`api.py` gebruikt de door HA geleverde `aiohttp`-sessie (`async_get_clientsession`), met een redelijke
timeout, en vertaalt HTTP/JSON/timeout-fouten naar één integratie-eigen exceptietype dat de coordinator
in `UpdateFailed` omzet. Radius km→nm binnen de client. Ruwe records worden naar een `dataclass`
genormaliseerd (met veilige coercions: `flight.strip()`, `alt_baro="ground"→0`, ontbrekend→`None`).
- *Waarom:* de client is los te unit-testen met een mock-sessie; normalisatie op één plek.

### D6 — Distributie via HACS, kwaliteit via CI
`hacs.json` + geldig `manifest.json` (met `version`, `iot_class: cloud_polling`, `config_flow: true`).
GitHub Actions: `home-assistant/actions/hassfest`, `hacs/action` (validate), en `pytest` voor de
pure-logic tests. Versiebeheer via git-tags → HACS-updateknop.

## Risks / Trade-offs

- **ADSB.lol fair-use / rate limits** → default polling documenteren; 10 s ≈ 8.640 req/dag/entry.
  Mitigatie: interval is configureerbaar (min 5 s), README noemt fair-use; overweeg 15 s als "vriendelijke" waarde in de docs.
- **Venster-clamping vs. testverwachting (D1)** → risico dat "parallel → loodrechte afstand"-test faalt
  bij ver vliegtuig/kort venster. Mitigatie: testcases kiezen met de loodrechte voet binnen `T`, en dit expliciet in `test_geo` documenteren.
- **Stale/onnauwkeurige ADS-B-posities** (`seen_pos`) → voorspelling op oude positie kan misleiden.
  Mitigatie: records met te hoge `seen_pos` (bijv. > 15 s) uitsluiten van approaching-detectie.
- **Entity-id's niet letterlijk zoals in de opdracht** bij meerdere entries (HA suffixt `_2`).
  Mitigatie: namen via device/locatienaam sturen; README maakt duidelijk dat de opdracht-id's illustratief zijn.
- **HA-versie-drift** voor de latere harness-tests → Mitigatie: die tests achter een aparte dev-dep en
  CI-matrix zetten; pure-logic tests blijven versie-onafhankelijk groen.
- **Privacy**: lat/lon gaat naar adsb.lol → Mitigatie: expliciete privacy-sectie in de README.

## Migration Plan

Nieuwe, op zichzelf staande repo — geen migratie van bestaande state. Deploy:
1. Repo aanmaken (`gh`), code + tests + CI, tag `v0.1.0`.
2. In HA: HACS → Custom repositories → repo-URL, categorie Integration → Install → HA herstarten.
3. Integratie toevoegen via Settings → Devices & services → Add Integration.
Rollback: integratie verwijderen in de UI + component uit HACS deïnstalleren; geen sporen buiten de
config-entry. De code raakt deze nixos-repo niet.

## Open Questions

- Exacte `seen_pos`-drempel en hysterese-factor/cooldown-waarden: redelijke defaults kiezen (bijv. 15 s
  / 1.3× / 60 s) en later op basis van praktijk bijstellen — verandert specs noch taakverdeling.
