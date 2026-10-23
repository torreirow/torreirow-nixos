# Plantwater-sensor (vrouwentong)

Zigbee-bodemvochtsensor `plantwater` in de pot van de vrouwentong (sansevieria). Die plant wil
grotendeels opdrogen tussen twee gietbeurten en rot bij te natte grond.

## Instellingen (op het device, via HA `number.plantwater_*`)

| Instelling                  | Waarde | Toelichting                                    |
| --------------------------- | ------ | ---------------------------------------------- |
| `soil_warning`              | 20 %   | daaronder zet de sensor `binary_sensor..._dry` |
| `soil_calibration`          | +5 %   | offset op bodemvocht                           |
| `soil_sampling`             | 30 s   | meetinterval bodem (kost accu, zie onder)      |
| `temperature_sampling`      | 30 s   | meetinterval temperatuur                       |
| `temperature/humidity_cal.` | 0      | geen offset                                    |

Meetinterval 30 s is ruim te vaak voor een plant; 1800–3600 s spaart de accu flink.

## Home Assistant — view "Helpers" (`dashboard-toorren`, pad `helpers`)

Sectie **Plantwater · Vrouwentong**: needle-gauge bodemvocht (rood <20 droog, groen 20–60,
oranje 60–80 nat, blauw >80 te nat), tiles temperatuur/luchtvochtigheid, badges accu + droog,
history 7 dagen en een entities-kaart met alle instellingen hierboven.
Sectie **Achterdeur** (2026-10-17 opgeknapt): heading met accu-badge; Mushroom-template
(icoon deur open/dicht, rood/groen, "Open/Dicht sinds 14:28 (1 uur)");
daaronder vier tiles (2×2):
- `sensor.achterdeursensor_achterdeur_open_vandaag` / `…_dicht_vandaag` — `history_stats`
  (count, state `on` resp. `off`, start `{{ today_at() }}`, eind `{{ now() }}`), UI-config-entries
  aangemaakt via de config-flow-REST-API. Let op: "dicht" telt ook `unavailable→off` na een
  herstart van HA/Zigbee mee, dus kan op zo'n dag hoger uitvallen dan "open".
- `sensor.achterdeur_laatst_open` / `sensor.achterdeur_laatst_dicht` — trigger-based
  template-sensors (timestamp) onderaan `configuration.yaml`; trigger-based zodat de waarde een
  herstart overleeft. Na toevoegen: `template.reload`, geen herstart.

Daaronder het logbook 48 u.

Opgeslagen via de websocket-API (`lovelace/config/save`, script draait in de HA-container met
aiohttp) — **geen HA-herstart nodig**, i.t.t. de `.storage` stop-edit-start-werkwijze.
Backups: `.storage/lovelace.dashboard_toorren.bak-claude-{plant,deur,deur2}-*`, `configuration.yaml.bak-claude-deur-*`.

Melding: HA-automation "Plantwater droog - Signal melding" (`notify.signal_maria`) bij `_dry` off→on.

## Grafana + alerts (in de repo)

- Dashboard `modules/monitoring/grafana/dashboards/torreiro/plantwater.json`
  (uid `plantwater-torreiro`, map torreiro): gauge, status, temp/vocht/accu nu + historie.
- Alerts `modules/monitoring/prometheus/alerts/plant-alerts.yml` → Telegram via alertmanager:
  - `PlantwaterDroog` — `_dry == 1` of bodemvocht < 20 %, 1 u lang
  - `PlantwaterBatterijLaag` — accu < 15 %, 6 u
  - `PlantwaterSensorOffline` — soil-entity unavailable, 6 u

De drempel 20 staat hardcoded in alert en Grafana (de `number.*`-entities worden niet naar
Prometheus geëxporteerd). Drempel in HA aangepast → ook hier aanpassen.

Grafana 12 bewaart provisioned dashboards in de `resource`-tabel (unified storage), niet meer
in `dashboard` — zoek daar bij controle via sqlite.
