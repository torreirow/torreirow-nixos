# Neerslag-indicator op Temp/Vocht-dashboard (HA + Grafana)

Buienradar-nowcast, dauwpunt-template-sensoren, de Grafana Neerslag-rij en Prometheus-verificatie.

> Verplaatst uit CLAUDE.md (Huidige Status) om de sessie-context slank te houden.

### Sessie 2026-09-22 - Neerslag-indicator op Temp/Vocht-dashboard - GROTENDEELS OPGELOST

**Doel:** Grafana-dashboard "Temperatuur & Luchtvochtigheid" uitbreiden met een neerslag-indicator.
OpenSpec change `add-neerslag-indicator`. Software-only, gratis, geen hardware/API-key.

**Kernbeslissing (uit explore):** luchtvochtigheid ≠ neerslag → data moet erbij, maar kan gratis via
**Buienradar** (core-integratie, keyloos). Buienradar's regen-nowcast is **radar-gebaseerd op de
eigen GPS-coords** (52.30/5.598, Ermelo), *niet* het dichtstbijzijnde station — lost "geen station
dicht bij Ermelo" op. KNMI/weerlive (golles/ha-knmi) en Met.no bewust niet gekozen: extra
afhankelijkheid, geen scherpere nowcast.

**HA-runtime doorgevoerd (malandro, `/var/lib/homeassistant` — BUITEN deze repo):**
- **Buienradar-integratie** toegevoegd via `.storage/core.config_entries` (entry
  `1f3fffed258e44dba73c11dc9d7d60e8`, `data`={lat,lon}, `options`={country_code:NL, delta:600,
  **timeframe:120** voor 2u-nowcast). Let op: config-flow schrijft alléén lat/lon in `data`; unique_id
  = `f"{lat}-{lon}"`. **Alle buienradar-sensoren zijn `entity_registry_enabled_default=False`** → ze
  registreren *disabled*; de drie neerslagsensoren handmatig ge-enabled in `.storage/core.entity_registry`
  (`disabled_by`→null). Entity-ids zijn NL-vertaald: `sensor.neerslagintensiteit` (mm/h nu),
  `sensor.neerslagverwachting_gemiddeld` (mm/h), `sensor.neerslagverwachting_totaal` (mm, 2u).
  Entities verschijnen pas ná de eerste geslaagde netwerk-fetch (`await data.async_update()` vóór
  `async_add_entities`).
- **Template-sensoren** in `configuration.yaml`: `sensor.buiten_dauwpunt` (Magnus a=17.625/b=243.04 uit
  `sensor.buitentempsensor_temperature`+`_humidity`, met `availability`), `sensor.buiten_dauwpunt_spread`
  (temp−dauwpunt), en samengestelde `sensor.neerslag_indicator` (volgorde `Regent`→`Bui op komst`→
  `Verzadigd`→`Droog`; radar leidend, dauwpunt vangt verzadiging die radar niet ziet). Startdrempels
  conservatief: regent >0.1 mm/h, bui op komst >0.2 mm, verzadigd spread ≤1 °C & RV ≥95 %.
- **Werkwijze:** stop→edit→start (2×), backups `*.bak-claude-20260922-*` van core.config_entries,
  core.entity_registry en configuration.yaml (2×). HA komt schoon op, geen template-errors.

**Geverifieerd via Prometheus (host `:9090`):** metricnamen exact als uit HA-broncode voorspeld —
`homeassistant_sensor_precipitation_intensity_mm_per_h` (deelt door neerslagintensiteit ÉN
_gemiddeld, onderscheiden via `entity`-label), `homeassistant_sensor_precipitation_mm` (totaal),
en dauwpunt onder `homeassistant_sensor_temperature_celsius` (buiten_dauwpunt=11.3, spread=3.2 —
klopt met Magnus voor 14.5 °C/81 %). Indicator `homeassistant_entity_available=1` (rendert; tekst
exporteert niet numeriek). **Geen Prometheus-glob-wijziging nodig** — `include_domains: sensor`
exporteert alles al. Belangrijk bij verificatie: recorder heeft `commit_interval: 30`, dus verse
sensoren staan pas na ~30s in `home-assistant_v2.db` — gebruik Prometheus, niet de recorder-DB.

**Repo-wijziging:** `modules/monitoring/grafana/dashboards/torreiro/temperature-humidity.json` — rij
"Neerslag" (panels id 30-33: stat "Neerslag nu" mm/h, stat "Verwacht komende 2u" mm, timeseries
"Neerslag verloop") + dauwpuntlijn (refId F) in de bestaande temperatuur-timeseries.

**Gedeployed:** `nixos-rebuild switch --flake .#malandro` gedraaid; `/etc/grafana/dashboards/torreiro/
temperature-humidity.json` bevat de Neerslag-rij, Grafana laadde het zonder error (de twee error-regels
in het grafana-journal zijn pre-existing kapotte dashboards `torreiro-monitoring.json` en
`atag-thermal-dashboard.json`, niet deze). Panelen tonen live data (neerslag 0 mm/h = droog, dauwpunt 12.3 °C).

**Nog open:** (6.1) drempels na enkele dagen data empirisch bijstellen.

**Status:** ✅ Live en geverifieerd (HA + Prometheus + Grafana). Alleen drempel-tuning (6.1) volgt na
enkele dagen data.
