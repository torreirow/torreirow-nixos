# Speedtest (Ookla-integratie in Home Assistant)

**Sinds 2026-10-15** meet HA de internetsnelheid met de HACS-integratie
[`soulripper13/hass-speedtest-ookla`](https://github.com/soulripper13/hass-speedtest-ookla)
(domain `ookla_speedtest`). Die verving de ingebouwde `speedtestdotnet`-integratie.

Alles leeft buiten de repo, in `/var/lib/homeassistant` (= `/config`) op malandro:

| Onderdeel    | Waar                                                                  |
| ------------ | --------------------------------------------------------------------- |
| Integratie   | `custom_components/ookla_speedtest/` (via HACS, updates via HACS)     |
| Ookla CLI    | `custom_components/ookla_speedtest/bin/speedtest.bin` (auto-download) |
| Config entry | UI: closest server, niet-manual, interval 1u, start `00:00:00`        |
| Customize    | `configuration.yaml` → `homeassistant.customize` (device_class)       |

## Entity-namen bewust gelijk gehouden

De integratie maakt `sensor.ookla_speedtest_*` aan. Die zijn in de entity-registry hernoemd naar
**`sensor.speedtest_*`**, de namen van de oude integratie. Daardoor:

- blijven de Prometheus-alerts (`modules/monitoring/prometheus/alerts/internet-alerts.yml`) en het
  Grafana-dashboard `internet-speed.json` werken zonder aanpassing;
- loopt de historie in Prometheus en de HA-recorder door;
- vallen de nieuwe sensoren (jitter, bufferbloat-grade, server, ISP) vanzelf onder de bestaande
  globs `sensor.speedtest_*` in `recorder` en het `prometheus`-filter.

## Valkuil: geen device_class

De Ookla-integratie zet **geen** `device_class` op download/upload/ping. De HA-Prometheus-exporter
bouwt de metricnaam uit device_class + eenheid, dus zonder device_class zou het
`homeassistant_sensor_unit_mbit_per_s` worden in plaats van
`homeassistant_sensor_data_rate_mbit_per_s` (en `_unit_ms` in plaats van `_duration_ms`). Daarom
staat in `homeassistant.customize`:

```yaml
sensor.speedtest_download: { device_class: data_rate }
sensor.speedtest_upload:   { device_class: data_rate }
sensor.speedtest_ping:     { device_class: duration }
```

Jitter heeft geen customize en verschijnt als `homeassistant_sensor_unit_ms`.

## Handmatig een test starten

```bash
T=$(sudo cat /run/agenix/homeassistant-prometheus-token | tr -d '\n')
curl -s -H "Authorization: Bearer $T" -H 'Content-Type: application/json' -d '{}' \
  http://localhost:8123/api/services/ookla_speedtest/run_speedtest
```
