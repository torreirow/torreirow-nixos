# Home Assistant - Data Retention (Bewaartermijn Sensordata)

**Locatie:** `/var/lib/homeassistant/configuration.yaml`
**Database:** `/var/lib/homeassistant/home-assistant_v2.db`

## Overzicht

Home Assistant is geconfigureerd met automatische data purging om de database beheersbaar te houden.

### Bewaartermijn Hiërarchie

1. **Uitgesloten (0 dagen):** Alleen datum/tijd sensoren
2. **Standaard (365 dagen / 1 jaar):** Alle andere entities (automation, binary sensors, battery, debug, etc.)
3. **Custom langere termijnen:**
   - Gas & Elektra: 3 jaar (1095 dagen)
   - ATAG One CV-ketel: 2 jaar (730 dagen)
   - Airco's: 2 jaar (730 dagen)
   - Zigbee energie: 3 jaar (1095 dagen)

## Recorder Configuratie

### Algemene Instellingen

```yaml
recorder:
  commit_interval: 30
  purge_keep_days: 365  # 1 jaar standaard bewaartermijn
  auto_purge: true
  auto_repack: true
```

- **commit_interval**: Database commits iedere 30 seconden
- **purge_keep_days**: Standaard bewaartermijn van 1 jaar (365 dagen) voor alle entities
- **auto_purge**: Automatisch oude data verwijderen
- **auto_repack**: Database optimaliseren na purge

## Bewaartermijn Overzicht

### Standaard - 1 jaar (365 dagen)

**Alle entities die niet expliciet geconfigureerd zijn krijgen automatisch 1 jaar bewaartermijn.**

Dit omvat onder andere:
- **Domeinen:** automation, updater, sun, weather, person, zone, input_boolean, script
- **Sensoren:** battery status, telefoon sensoren, update sensoren, binary sensors
- **Debug data:** debug sensoren, PCB temperatuur, boiler retour temperatuur, foutmeldingen
- **En alle andere niet-expliciet geconfigureerde entities**

### Uitgesloten van Opslag (0 dagen)

**Alleen datum/tijd sensoren** worden volledig uitgesloten:
- `sensor.date*` - Datum sensoren
- `sensor.time*` - Tijd sensoren

**Rationale:** Deze sensoren veranderen continue en hebben geen historische waarde.

## Custom Bewaartermijnen (Override Standaard)

Specifieke entities hebben langere bewaartermijnen dan de standaard 1 jaar:

### Gas en Elektra - 3 jaar (1095 dagen)

**Waarom 3 jaar?** Langetermijn energieverbruik analyse, jaarlijkse vergelijkingen.

**Entities:**
- `sensor.gas_meter_*` - Alle gas meter sensoren
- `sensor.electricity_meter_*verbruik*` - Elektriciteit verbruik
- `sensor.electricity_meter_*productie*` - Elektriciteit productie (zonnepanelen)
- `sensor.*_cost` - Kosten berekeningen

**Specifieke sensoren:**
```yaml
sensor.gas_meter_gasverbruik: 1095 dagen
sensor.electricity_meter_energieverbruik: 1095 dagen
sensor.electricity_meter_energieverbruik_tarief_1: 1095 dagen
sensor.electricity_meter_energieverbruik_tarief_2: 1095 dagen
sensor.electricity_meter_energieproductie: 1095 dagen
sensor.electricity_meter_energieproductie_tarief_1: 1095 dagen
sensor.electricity_meter_energieproductie_tarief_2: 1095 dagen
```

### ATAG One (CV-ketel) - 2 jaar (730 dagen)

**Waarom 2 jaar?** Seizoensgebonden klimaatdata analyse, stookgedrag vergelijken.

**Entity patterns:**
- `sensor.atag_one_kamer_temp` - Kamertemperatuur
- `sensor.atag_one_buiten_temp` - Buitentemperatuur
- `sensor.atag_one_brander` - Brander status
- `sensor.atag_one_gasverbruik` - Gasverbruik CV
- `sensor.atag_one_cv_*` - CV gerelateerde sensoren
- `sensor.atag_one_dhw_*` - Warm water sensoren
- `sensor.atag_one_gemiddelde_buiten_temp` - Gemiddelde buitentemperatuur
- `climate.atag_one` - Thermostaat

### SmartThings Airco's - 2 jaar (730 dagen)

**Waarom 2 jaar?** Seizoensgebonden koelgedrag analyse.

**Entity patterns:**
- `climate.*` - Alle climate entities
- `sensor.*airco*` - Airco sensoren
- `sensor.*airconditioner*` - Airconditioner sensoren

### Zigbee Energie Monitoring - 3 jaar (730 dagen)

**Waarom 3 jaar?** Langetermijn apparaat verbruik analyse.

**Entity patterns:**
- `sensor.*plug*energy` - Smart plug energie verbruik
- `sensor.*plug*power` - Smart plug vermogen

### Neerslag/regen (Buienradar + indicator) - 1 jaar (365 dagen)

**Waarom bewaren?** Historie van de neerslag-indicator en de Buienradar-nowcast volgen.

**Entity patterns:**
- `sensor.neerslag*` - dekt `sensor.neerslagintensiteit` (mm/h, heeft `state_class` →
  ook long-term statistics), `sensor.neerslagverwachting_gemiddeld`,
  `sensor.neerslagverwachting_totaal` en de template `sensor.neerslag_indicator`

> **Let op — `include` sluit de rest uit.** Zodra `recorder.include` bestaat, worden entities
> die er NIET in staan niet opgeslagen (ook al is `purge_keep_days` 365). Daardoor hadden de
> neerslag-sensoren geen state-historie: `sensor.neerslagintensiteit` kreeg wél hourly
> long-term statistics (via `state_class`), maar nul detail-states. Opgelost door
> `sensor.neerslag*` aan `include.entity_globs` toe te voegen (2026-10-08). Een recorder-
> wijziging werkt pas na een **HA-herstart**.

### Plantwater-sensor - 1 jaar (365 dagen)

**Waarom bewaren?** Bodemvocht-/klimaathistorie van de plant volgen.

**Entity patterns:**
- `sensor.plantwater_*` - bodemvocht (`_soil_moisture`), luchtvochtigheid (`_humidity`),
  temperatuur (`_temperature`), accu (`_battery`)
- `binary_sensor.plantwater_dry` - droog-melding (triggert de Signal-automatie
  "Plantwater droog - Signal melding" → `notify.signal_maria`)

## Database Statistieken

**Database grootte:** ~598 MB (2026-10-08, na opruimen van System Monitor)
- Was opgelopen tot **1,4 GB** (73 % System Monitor); na het uit de recorder halen +
  `recorder.purge` (`apply_filter` + `repack`) terug naar ~598 MB.
- `home-assistant_v2.db`: ~598 MB
- `home-assistant_v2.db-wal`: Write-Ahead Log (groeit tijdelijk sterk tijdens een VACUUM/repack)
- `home-assistant_v2.db-shm`: Shared Memory

## Bewaartermijn Aanpassen

### Per Entity Type (Bulk)

Voeg toe aan `recorder.include.entity_globs`:
```yaml
recorder:
  include:
    entity_globs:
      - sensor.new_sensor_*
```

### Per individuele sensor — LET OP: bestaat niet

> **Misvatting:** HA-recorder kent **geen** bewaartermijn-per-entity. `recorder.include`
> bepaalt alléén **óf** iets wordt opgeslagen, niet **hoe lang** — en `recorder_purge_keep_days`
> via `homeassistant.customize` is **geen bestaande HA-optie**. Alle opgeslagen entities vallen onder
> de globale `purge_keep_days: 365`. De comments "30 dagen bewaren" bij diverse include-globs
> (System Monitor, Speedtest, Stookwijzer) zijn dus **niet afgedwongen** — die werden gewoon een jaar
> bewaard.
>
> Wil je een hoog-frequente sensor écht korter bewaren, dan is de enige weg hem **uit `include`** te
> halen (stopt opslag) en zijn historie te purgen met `recorder.purge_entities`, of periodiek
> `recorder.purge_entities` via een automation te draaien.

### System Monitor — uit de recorder gehaald (2026-10-08)

De `sensor.system_monitor_*`-sensoren (CPU/geheugen/temp) veranderen elke ~10-15 s en vormden
**~4,6 miljoen rijen ≈ 73 %** van de DB (die was opgelopen tot **1,4 GB**). Ze zijn uit de
`recorder.include` gehaald en hun historie is gepurged + gerepackt. De data blijft beschikbaar in
**Prometheus/Grafana** (de `server-health`-dashboards), waar systeem-observability thuishoort — de
Prometheus-exporter-filter (`prometheus.filter.include_entity_globs`) houdt `sensor.system_monitor_*`
dus wél.

## Database Maintenance

### Handmatige Purge

Via Developer Tools → Services:
```yaml
service: recorder.purge
data:
  keep_days: 30
  repack: true
```

### Database Grootte Monitoren

```bash
# Database grootte checken
ls -lh /var/lib/homeassistant/home-assistant_v2.db

# SQLite vacuum (compactie)
sqlite3 /var/lib/homeassistant/home-assistant_v2.db "VACUUM;"
```

## Best Practices

1. **Bewaartermijn afstemmen op gebruik:**
   - Energie: 3 jaar (belastingaangifte)
   - Klimaat: 2 jaar (seizoensvergelijking)
   - Debug/tijdelijke data: Exclude

2. **Database grootte in de gaten houden:**
   - Target: < 500 MB
   - Bij > 1 GB: Purge settings aanscherpen

3. **Backup strategie:**
   - Regelmatig backups maken van `/var/lib/homeassistant/`
   - Database exporteren voor langetermijn archivering

4. **Exclude binary sensors:**
   - Binary sensors (aan/uit) genereren veel data
   - Alleen include indien echt nodig voor analyse

## Links

- [Home Assistant Recorder Documentation](https://www.home-assistant.io/integrations/recorder/)
- [Database Performance Tips](https://www.home-assistant.io/docs/backend/database/)
