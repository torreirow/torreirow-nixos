## Context

Zie proposal.md — Why. Het dashboard "Temperatuur & Luchtvochtigheid"
(`modules/monitoring/grafana/dashboards/torreiro/temperature-humidity.json`) wordt gevoed door
Prometheus, die Home Assistant-sensormetrics scrapet. HA draait als Docker-container op malandro;
de HA-config leeft in `/var/lib/homeassistant` (`.storage/` + `configuration.yaml`) — **buiten deze
nixos-repo**. Alleen het dashboard-JSON zit in de repo.

Tijdens explore geverifieerde feiten die de aanpak bepalen:

- **Geen weather-integratie, geen neerslagdata** aanwezig; er is geen regenmeter. HA home-coords
  zijn `52.30 / 5.598` (Ermelo).
- **Prometheus-export exporteert alle sensoren**: `include_domains` bevat `sensor`, dus nieuwe
  sensoren worden automatisch gescrapet. Bewijs: `sensor.buitentempsensor_temperature` matcht geen
  enkele `include_entity_globs`-regel maar staat wél in Prometheus (13.5 °C gemeten). De glob-lijst
  is cosmetisch.
- **Buienradar-sensoren en hun Prometheus-metricnamen** (uit de HA-broncode geverifieerd):

  | HA-sensor                          | eenheid | device_class            | Prometheus-metric                                       |
  |------------------------------------|---------|-------------------------|---------------------------------------------------------|
  | `precipitation` (nu)               | mm/h    | `precipitation_intensity` | `homeassistant_sensor_precipitation_intensity_mm_per_h` |
  | `precipitation_forecast_average`   | mm/h    | `precipitation_intensity` | `homeassistant_sensor_precipitation_intensity_mm_per_h` |
  | `precipitation_forecast_total`     | mm      | `precipitation`         | `homeassistant_sensor_precipitation_mm`                 |

  `precipitation` en `..._forecast_average` delen dezelfde metric → in PromQL onderscheiden via het
  `entity`-label. `precipitation_forecast_timeframe` bestaat niet als entity; het venster is de
  config-optie `timeframe` (5–120 min).

## Goals / Non-Goals

**Goals:**

- Een neerslag-indicator toevoegen aan het bestaande dashboard, gratis en zonder hardware.
- De radar-nowcast (gezaghebbend voor echte neerslag) en een lokaal dauwpunt (verzadigingssignaal
  dat de radar niet ziet) in één samengestelde toestand combineren.
- Eerlijk zijn over wat elk signaal kan; geen suggestie van meetnauwkeurigheid die er niet is.

**Non-Goals:**

- Geen fysieke regenmeter, barometer of PWS (bewust uitgesteld naar een eventuele fase 2 —
  ground-truth-blending). Zonder barometer is er geen echte voorspellende lead-time; de indicator
  leunt voor "op komst" volledig op Buienradar.
- Geen tweede weerbron (KNMI/weerlive/Met.no); Buienradar dekt de nowcast met dezelfde nationale
  radar.
- Geen wijziging aan de Prometheus-export of scrape-config.

## Decisions

**Buienradar (core, keyloos) als neerslagbron — niet KNMI/weerlive of Met.no.**
Buienradar is een HA-core-integratie zonder API-key en levert een radar-gebaseerde punt-nowcast op
de eigen GPS-coördinaten. Dat lost precies de "geen station dicht bij Ermelo"-zorg op: de nowcast
komt van de nationale radar-compositie op een ~1 km grid, niet van een ver meetstation.
*Alternatieven:* golles/ha-knmi (weerlive) vereist een API-key met dagelimiet en is
forecast- i.p.v. radar-nowcast-georiënteerd; Met.no heeft geen NL-radar-nowcast. Beide voegen een
afhankelijkheid toe zonder scherpere nowcast.

**`timeframe: 120` minuten.** Maximaliseert het nowcast-venster (max 120 = 2 uur) → "bui op komst"
kijkt zo ver mogelijk vooruit binnen wat de radar-nowcast kan.

**Dauwpunt via Magnus-formule in HA template-sensor** (a = 17.625, b = 243.04 °C), gevoed door
`sensor.buitentempsensor_temperature` + `sensor.buitentempsensor_humidity`. Levert
`sensor.buiten_dauwpunt` en `sensor.buiten_dauwpunt_spread`. Device_class `temperature` → exporteert
onder de bestaande `homeassistant_sensor_temperature_celsius`-metric, dus meteen bruikbaar in het
dashboard. *Alternatief:* dauwpunt puur in PromQL/Grafana berekenen — kan, maar de logaritme en de
`unavailable`-afhandeling zijn in een HA-template schoner en herbruikbaar door andere automations.

**Samengestelde `sensor.neerslag_indicator` als HA template-sensor, radar leidend.** Volgorde van
evaluatie: `Regent` (radar nu) → `Bui op komst` (radar-nowcast) → `Verzadigd` (dauwpunt-heuristiek
alleen als de radar droog zegt) → `Droog`. Zo kan de zwakke heuristiek (false positives bij
mist/dauw) nooit een echte radarmelding overschrijven. *Alternatief:* de logica in Grafana leggen —
maar dan is de toestand niet herbruikbaar voor HA-automations/meldingen en zit de businesslogica in
een dashboard.

**Alleen het dashboard-JSON in de repo; alle HA-config als runtime-edit.** Consistent met eerdere
sessies (agenda-wandpaneel, afzuiging): `.storage`/`configuration.yaml` worden op de draaiende HA
bewerkt (integratie via config-flow of `.storage/core.config_entries`; template-sensoren in
`configuration.yaml`), met backups en HA-stop bij `.storage`-edits.

## Risks / Trade-offs

- **Drempelwaarden zijn nog niet empirisch geijkt** → start met conservatieve defaults (`Regent`
  > 0.1 mm/h; `Bui op komst` totaal > ~0.2 mm; `Verzadigd` spread ≤ 1 °C én RV ≥ 95 %) en stel bij
  na enkele dagen data. Opgenomen als expliciete verificatietaak.
- **`Verzadigd` heeft false positives** (mist/dauw, vooral nacht/ochtend) en de heuristiek mist
  regen uit drogere lucht → daarom is de toestand bewust apart benoemd en nooit als "regen"
  gepresenteerd; radar blijft leidend.
- **Geen lead-time zonder barometer** → "op komst" is puur radar-nowcast; dat is een bewuste
  fase-1-grens (zie Non-Goals), geen defect.
- **Metricnamen live nog te bevestigen** → uit broncode geverifieerd, maar na installatie in
  Prometheus checken vóór de PromQL-queries definitief worden; bij afwijking desnoods normaliseren
  met een template-sensor met expliciete `device_class`.
- **Buienradar-uitval/rate-limit** → sensoren worden `unavailable`; de dauwpunt-heuristiek blijft
  lokaal werken, dus het dashboard toont dan nog steeds verzadiging. Best-effort, geen alerting.

## Migration Plan

1. HA-runtime: Buienradar-integratie toevoegen (`timeframe: 120`), verifiëren dat de drie
   neerslagsensoren bestaan.
2. HA-runtime: template-sensoren (dauwpunt, spread, indicator) toevoegen in `configuration.yaml`,
   HA herladen, verifiëren.
3. Bevestigen dat de nieuwe metrics in Prometheus verschijnen onder de verwachte namen.
4. Repo: dashboard-JSON uitbreiden met de rij "Neerslag" + dauwpuntlijnen; Grafana-provisioning
   herlaadt het dashboard.
5. Na enkele dagen: drempels bijstellen.

**Rollback:** dashboard-JSON teruggezet via git; HA-integratie en template-sensoren verwijderen +
`configuration.yaml`-backup terugzetten. Geen data-migratie, geen onomkeerbare stappen.
