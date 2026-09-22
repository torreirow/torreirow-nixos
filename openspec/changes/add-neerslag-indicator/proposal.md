## Why

Het Grafana-dashboard "Temperatuur & Luchtvochtigheid" toont buiten-temperatuur en
-luchtvochtigheid, maar geen neerslag. Luchtvochtigheid is géén neerslag-vervanger: 95% RV kan
mist of dauw zijn (false positive), en regen kan uit drogere lucht vallen (false negative).
Neerslag is een aparte meetgrootheid die er dus bij moet — maar dat kan gratis, zonder hardware
en zonder API-key, door Buienradar's radar-nowcast (punt-gebaseerd op de eigen GPS-coördinaten,
dus geldig voor Ermelo ondanks het ontbreken van een meetstation dichtbij) te combineren met een
lokaal berekend dauwpunt.

## What Changes

- **Buienradar core-integratie** toevoegen in Home Assistant (keyloos, `timeframe: 120` voor een
  2-uurs nowcast). Levert `precipitation` (mm/h nu), `precipitation_forecast_average` (mm/h) en
  `precipitation_forecast_total` (mm komende 2u).
- **Dauwpunt-heuristiek** als HA template-sensoren: `sensor.buiten_dauwpunt` (Magnus-formule uit de
  bestaande Zigbee buiten-sensor) en `sensor.buiten_dauwpunt_spread` (temp − dauwpunt).
- **Samengestelde `sensor.neerslag_indicator`** met vier eerlijke toestanden: `Regent`,
  `Bui op komst`, `Verzadigd` (mist/dauw — wat de radar niet ziet) en `Droog`.
- **Grafana-dashboarduitbreiding**: nieuwe rij "Neerslag" in `temperature-humidity.json` met
  neerslag-nu, verwachting-2u, een neerslag-verloopgrafiek, en dauwpunt/spread bij de bestaande
  temp/vocht-grafieken.
- **Geen** wijziging aan de Prometheus-export nodig: `include_domains` bevat `sensor`, dus alle
  nieuwe sensoren worden automatisch gescrapet (geverifieerd).

## Capabilities

### New Capabilities
- `neerslag-indicator`: Een neerslag-indicator voor het temperatuur/vocht-dashboard, gevoed door
  Buienradar's punt-nowcast plus een lokaal berekende dauwpunt-heuristiek, met een samengestelde
  toestand en Grafana-visualisatie.

### Modified Capabilities
<!-- Geen bestaande capability met spec-level requirements wordt gewijzigd. -->

## Impact

- **HA-runtime** (`/var/lib/homeassistant`, buiten deze nixos-repo): nieuwe Buienradar-integratie
  (`.storage/core.config_entries`) en nieuwe template-sensoren in `configuration.yaml`. Bewerken
  volgens de vaste `.storage`-werkwijze (HA stoppen bij `.storage`-edits, backups maken).
- **nixos-repo** (deze repo): uitsluitend `modules/monitoring/grafana/dashboards/torreiro/temperature-humidity.json`.
- **Databronnen/dependencies**: Buienradar (gratis, keyloos, publieke API); geen nieuwe secrets,
  geen hardware, geen kosten.
- **Risico**: drempelwaarden voor de indicator-toestanden moeten na een paar dagen data empirisch
  worden afgesteld; Prometheus-metricnamen zijn uit de HA-broncode geverifieerd maar worden na
  installatie live bevestigd.
