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

## Database Statistieken

**Database grootte:** ~133 MB (maart 2026)
- `home-assistant_v2.db`: 133 MB
- `home-assistant_v2.db-wal`: 4.1 MB (Write-Ahead Log)
- `home-assistant_v2.db-shm`: 32 KB (Shared Memory)

## Bewaartermijn Aanpassen

### Per Entity Type (Bulk)

Voeg toe aan `recorder.include.entity_globs`:
```yaml
recorder:
  include:
    entity_globs:
      - sensor.new_sensor_*
```

### Per Individuele Sensor

Voeg toe aan `homeassistant.customize`:
```yaml
homeassistant:
  customize:
    sensor.nieuwe_sensor:
      recorder_purge_keep_days: 365
```

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
