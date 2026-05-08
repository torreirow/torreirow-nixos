# Home Assistant Prometheus Integratie

Configuratie voor het exporteren van Home Assistant metrics naar Prometheus.

## Datum
2026-03-22

## Overzicht

Home Assistant exposeert metrics via de Prometheus integratie op endpoint `/api/prometheus`. Deze metrics worden door Prometheus gescraped en kunnen gebruikt worden voor monitoring, alerting en visualisatie in Grafana.

## Geconfigureerde Metrics

De volgende entity types worden geëxporteerd:

### Energy Sensors
- `sensor.electricity_meter_*` - Elektriciteitsverbruik en productie
- `sensor.gas_meter_*` - Gasverbruik
- `sensor.*_energy` - Alle energie-gerelateerde sensors
- `sensor.*_power` - Vermogen sensors

### Door Sensors
- `binary_sensor.*deur*` - Alle deur sensors (inclusief achterdeur)
- `binary_sensor.*door*` - Door sensors (Engelstalig)

## Configuratie Bestanden

### 1. Home Assistant configuratie
**Locatie:** `/var/lib/homeassistant/configuration.yaml`

De Prometheus integratie is toegevoegd:

```yaml
# Prometheus integratie - metrics export
prometheus:
  namespace: homeassistant
  filter:
    include_domains:
      - sensor
      - binary_sensor
    include_entity_globs:
      # Energy sensors
      - sensor.electricity_meter_*
      - sensor.gas_meter_*
      - sensor.*_energy
      - sensor.*_power
      # Door sensors
      - binary_sensor.*deur*
      - binary_sensor.*door*
```

### 2. Prometheus scrape configuratie
**Locatie:** `modules/monitoring/prometheus/prometheus-homeassistant.nix`

```nix
services.prometheus.scrapeConfigs = lib.mkAfter [
  {
    job_name = "homeassistant";
    scrape_interval = "60s";
    metrics_path = "/api/prometheus";
    bearer_token_file = "/var/lib/prometheus/homeassistant-bearer-token";
    static_configs = [{
      targets = [ "localhost:8123" ];
      labels = {
        instance = "homeassistant";
      };
    }];
  }
];
```

## Setup Instructies

### Stap 1: Maak Long-Lived Access Token

1. Ga naar **https://homeassistant.toorren.net**
2. Klik op je profiel (linkerbenedenhoek)
3. Scroll naar **Long-Lived Access Tokens**
4. Klik **CREATE TOKEN**
5. Naam: `prometheus`
6. **Kopieer het token** (format: `eyJhbGciOiJIUzI1NiIsInR5cCI6...`)

   ⚠️ **Let op:** Je ziet het token maar één keer! Kopieer het direct.

### Stap 2: Bewaar Token op Server

Voer dit commando uit (vervang `YOUR_TOKEN` met je gekopieerde token):

```bash
echo "Bearer YOUR_TOKEN_HERE" | sudo tee /var/lib/prometheus/homeassistant-bearer-token
sudo chown prometheus:prometheus /var/lib/prometheus/homeassistant-bearer-token
sudo chmod 600 /var/lib/prometheus/homeassistant-bearer-token
```

### Stap 3: Deploy Configuratie

```bash
sudo nixos-rebuild switch --flake .#malandro
```

### Stap 4: Verificatie

#### Check Prometheus Target

```bash
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.scrapePool == "homeassistant")'
```

**Verwachte output:**
```json
{
  "discoveredLabels": {...},
  "labels": {
    "instance": "homeassistant",
    "job": "homeassistant"
  },
  "scrapePool": "homeassistant",
  "scrapeUrl": "http://localhost:8123/api/prometheus",
  "health": "up",
  "lastError": "",
  "lastScrape": "2026-03-22T...",
  "lastScrapeDuration": 0.123,
  "scrapeInterval": "1m0s",
  "scrapeTimeout": "10s"
}
```

#### Check Beschikbare Metrics

```bash
curl -s http://localhost:9090/api/v1/label/__name__/values | jq '.data[] | select(contains("homeassistant"))'
```

#### Test Specifieke Metric

Voorbeeld: Elektriciteitsverbruik query
```bash
curl -s -G http://localhost:9090/api/v1/query \
  --data-urlencode 'query=homeassistant_sensor_state{entity="sensor.electricity_meter_energieverbruik"}' \
  | jq '.'
```

## Troubleshooting

### Home Assistant metrics endpoint geeft 401 Unauthorized

**Oorzaak:** Token niet correct geconfigureerd of verlopen.

**Oplossing:**
1. Check of token bestand bestaat: `sudo ls -l /var/lib/prometheus/homeassistant-bearer-token`
2. Check token format (moet beginnen met "Bearer "): `sudo head -c 50 /var/lib/prometheus/homeassistant-bearer-token`
3. Maak indien nodig een nieuw token aan in Home Assistant

### Prometheus target toont "down"

**Check de logs:**
```bash
sudo journalctl -u prometheus -n 50 --no-pager | grep homeassistant
```

**Mogelijke oorzaken:**
- Token verlopen of incorrect
- Home Assistant container niet bereikbaar
- Firewall blokkeert verkeer

### Geen metrics zichtbaar in Prometheus

**Check of Home Assistant Prometheus integratie actief is:**
```bash
sudo grep -A 10 "prometheus:" /var/lib/homeassistant/configuration.yaml
```

**Check of entities matchen met de filters:**
1. Ga naar Home Assistant → Developer Tools → States
2. Zoek naar je energy/door sensors
3. Kopieer de exacte entity IDs
4. Pas indien nodig de filters aan in `/var/lib/homeassistant/configuration.yaml`
5. Herstart Home Assistant: `docker restart homeassistant`

## Metrics Voorbeelden

### Elektriciteitsverbruik (kWh)
```promql
homeassistant_sensor_state{entity=~"sensor.electricity_meter.*"}
```

### Gasverbruik (m³)
```promql
homeassistant_sensor_state{entity=~"sensor.gas_meter.*"}
```

### Achterdeur Status (open/closed)
```promql
homeassistant_binary_sensor_state{entity=~"binary_sensor.*deur.*"}
```

### Alle energy metrics
```promql
homeassistant_sensor_state{entity=~".*energy.*"}
```

## Grafana Dashboard

De metrics kunnen in Grafana worden gevisualiseerd via:
- **URL:** https://grafana.toorren.net
- **Datasource:** Prometheus
- **Dashboard:** Maak een nieuw dashboard met Home Assistant metrics

### Voorbeeld Panel Query

**Elektriciteitsverbruik per uur:**
```promql
rate(homeassistant_sensor_state{entity="sensor.electricity_meter_energieverbruik"}[1h])
```

## Configuratie Aanpassen

### Extra entities toevoegen

Edit `/var/lib/homeassistant/configuration.yaml`:

```yaml
prometheus:
  namespace: homeassistant
  filter:
    include_entity_globs:
      # Bestaande filters...
      # Nieuwe filters toevoegen:
      - sensor.mijn_nieuwe_sensor_*
      - binary_sensor.beweging_*
```

Herstart Home Assistant:
```bash
docker restart homeassistant
```

### Scrape interval aanpassen

Edit `modules/monitoring/prometheus/prometheus-homeassistant.nix`:

```nix
scrape_interval = "30s";  # Was: 60s
```

Deploy:
```bash
sudo nixos-rebuild switch --flake .#malandro
```

## Referenties

- [Home Assistant Prometheus Integration Docs](https://www.home-assistant.io/integrations/prometheus/)
- [Prometheus Configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)
- Prometheus config: `modules/monitoring/prometheus/prometheus-homeassistant.nix`
- Home Assistant config: `/var/lib/homeassistant/configuration.yaml`
