# Stookwijzer Template Sensors Setup

## Automatische deployment

De template file `templates/stookwijzer.yaml` wordt automatisch gekopieerd naar `/var/lib/homeassistant/templates/` bij elke `nixos-rebuild`.

## Home Assistant configuratie

Voeg dit toe aan `/var/lib/homeassistant/configuration.yaml`:

```yaml
# Include template directory
template: !include_dir_merge_list templates/
```

Of als je al een `template:` sectie hebt, zorg dat deze de templates directory include.

## Na configuratie

1. Check de configuratie in Home Assistant: **Instellingen** → **Systeem** → **Check configuratie**
2. Herstart Home Assistant
3. Controleer of de sensors beschikbaar zijn:
   - `sensor.stookwijzer_forecast_6h`
   - `sensor.stookwijzer_forecast_12h`

## Dashboard

Gebruik het aangepaste dashboard in `homeassistant-dashboard-weather-complete.yaml` voor de volledige stookwijzer card met:
- Hoofdadvies bar (code_yellow/orange/red)
- Windsnelheid en luchtkwaliteit gauges
- Forecast bars voor +6u en +12u
- Gedetailleerde lijst met alle waarden
- History graph

## Troubleshooting

### Templates worden niet geladen

Check `/var/lib/homeassistant/templates/stookwijzer.yaml` bestaat en leesbaar is voor Home Assistant.

### Sensors blijven "unknown"

1. Check of de `sensor.stookwijzer_advice` entity bestaat
2. Check de logs: **Instellingen** → **Systeem** → **Logs**
3. Trigger handmatig: **Ontwikkelaarstools** → **Services** → `stookwijzer.get_forecast`
