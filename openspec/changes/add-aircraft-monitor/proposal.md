## Why

Wij willen in Home Assistant kunnen zien welke vliegtuigen richting een opgegeven GPS-locatie
vliegen en tijdig een melding krijgen wanneer een toestel binnen een instelbare afstand van die
locatie zal komen (bijv. "vliegtuig komt over het huis"). Er bestaat geen bestaande HA-integratie
die op basis van de gratis publieke **ADSB.lol** API een *voorspelde closest approach* berekent en
daar dedup-vrije events op afvuurt. Deze change levert een production-quality custom integration die
dat doet en tegelijk de basis legt voor meerdere te bewaken locaties (Home / Camping / Werk).

## What Changes

- **Nieuwe standalone repository** `torreirow/home-assistant-aircraft-monitor` (publiek, MIT), geen
  wijziging aan deze nixos-repo. Distributie via **HACS custom repository** (HA draait als Docker-
  container, geen HAOS/Supervisor → geen Nix-module en geen add-on-repo).
- **Custom integration** `custom_components/aircraft_monitor/` met een `DataUpdateCoordinator` die
  centraal de ADSB.lol API pollt binnen een configureerbare zoekradius.
- **Geo-module** met pure functies voor een geografisch correcte *predicted closest approach*
  (lokaal tangentieel vlak, analytische vector-oplossing) — het vliegtuig moet daadwerkelijk naar de
  locatie toe bewegen én de voorspelde baan moet binnen `alert_distance` komen binnen `prediction_time`.
- **Config-flow + options-flow** (volledige UI-configuratie): latitude, longitude, search radius,
  alert distance, prediction time, polling interval, min/max hoogte, min snelheid — met validatie.
  Locatie/tunables zijn **nooit hardcoded**; het zijn uitsluitend defaults.
- **Multi-entry architectuur**: 1 ConfigEntry = 1 locatie = 1 device met eigen entities, zodat later
  meerdere locaties bewaakt kunnen worden zonder herontwerp.
- **Entities**: `sensor` aircraft count, nearest aircraft, approaching aircraft; `binary_sensor`
  aircraft approaching — met de gevraagde attributen.
- **Custom event** `aircraft_monitor.aircraft_approaching` met flank-getriggerde **duplicate-
  prevention** (state-machine per `hex`, met hysterese en cooldown).
- **Robuuste foutafhandeling**: connection/timeout/HTTP/JSON-fouten laten de integratie niet crashen;
  ontbrekende/`null`/ongeldige velden worden veilig behandeld (`flight.strip()`, `alt_baro="ground"`,
  stale `seen_pos`).
- **Tests** (pure logic eerst, geen internet/HA-versie-afhankelijkheid): `test_geo`, `test_api`,
  `test_coordinator`. HA-testharness-tests (`config_flow`, `sensor`) als expliciete follow-up.
- **HACS-metadata + CI** (`hacs.json`, `manifest.json`, GitHub Actions: hassfest + HACS-validate +
  pytest) en een uitgebreide README (installatie, configuratie, entities, automation-voorbeeld,
  troubleshooting, API-info, privacy).

## Capabilities

### New Capabilities
- `aircraft-monitoring`: Periodiek ADS-B-data ophalen, per vliegtuig de closest approach t.o.v. een
  geconfigureerde locatie voorspellen, relevante entities aanbieden en een dedup-vrij approaching-event
  afvuren, volledig configureerbaar via de HA-UI en geschikt voor meerdere locaties.

### Modified Capabilities
<!-- Geen bestaande capabilities gewijzigd; dit is een nieuwe, op zichzelf staande integratie. -->

## Impact

- **Nieuwe externe repository**: `torreirow/home-assistant-aircraft-monitor` (code leeft dáár, niet in
  deze nixos-repo). Deze OpenSpec-change beschrijft en stuurt die bouw.
- **Externe afhankelijkheid**: ADSB.lol publieke API (`https://api.adsb.lol/v2/lat/{lat}/lon/{lon}/dist/{nm}`),
  geen API-key. Radius in km → nm (`/1.852`). Fair-use: default polling 10 s ≈ 8.640 requests/dag/entry.
- **HA-runtime**: geïnstalleerd via HACS in de bestaande Docker-HA (`/var/lib/homeassistant/custom_components/`);
  HA blijft eigenaar van polling, state, events, entities en lifecycle. Geen systemd-service, geen
  wijziging aan `modules/hassio`.
- **Privacy**: de geconfigureerde lat/lon wordt naar adsb.lol gestuurd als query — te documenteren in de README.
- **Afhankelijkheden (integratie)**: alleen wat HA al levert (`aiohttp` via HA); geen extra runtime-deps.
  Dev/test: `pytest` (+ later `pytest-homeassistant-custom-component` voor de harness-tests).
