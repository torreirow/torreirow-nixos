# Proposal

## Why

De ATAG One-dashboards tonen op meerdere punten onzin. De gasgrafieken draaien op de
boiler-eigen schatting `sensor.atag_one_gas`, die ~11× te laag is: live gemeten op malandro
(Prometheus, 14-daags venster, 2026-10-08) liep die teller +1,0 m³ terwijl de échte P1/DSMR-
huismeter `sensor.gas_meter_gasverbruik` +11,5 m³ deed bij +9,55 branduren (11,5 ÷ 9,55 ≈
1,2 m³/h — fysisch correct voor een modulerende combi). Daarnaast tonen panelen voor sensoren
die structureel 0 zijn, haalt één bogus buitentemp-meting (−100 °C op 7 okt) gemiddelden en
minimums onderuit, en zijn de "(24u)"-panelen niet over een andere periode te bekijken.

## What Changes

- **Gasmeting herstellen**: de gas-panelen in `atag-boiler.json` draaien op de echte P1-meter
  `sensor.gas_meter_gasverbruik` in plaats van de kapotte boiler-schatting `sensor.atag_one_gas`.
- **Buitentemp-outlierfilter**: elke buitentemp-query krijgt een `> -40`-filter, zodat een
  bogus −100 °C-meting gemiddelden/minimums niet meer verpest (5 plekken).
- **Dode panelen weg**: panelen voor sensoren die structureel 0 zijn (branderstarts,
  warmwaterdoorstroming, opwarmtijd) worden verwijderd. Brander-percentage werkt wél en blijft.
- **Dode alert weg**: `ATAGBurnerCyclingExcessive` draait op `increase()` van een constante 0 en
  kan per definitie nooit afgaan — verwijderd.
- **Brandtijd via teller**: brandtijd wordt afgeleid uit de `branduren`-teller, niet uit het
  5-min-gesamplede brander-percentage (dat korte tapbeurten mist).
- **"(24u)"-panelen periode-afhankelijk**: hardcoded `[24h]`/`[24h:5m]`-vensters op het
  Thermal-dashboard worden `$__range`, zodat ze de tijdkiezer volgen.

## Capabilities

### New Capabilities
- `atag-boiler-monitoring`: hoe de ATAG One CV-ketel- en verwarmingsdata gevisualiseerd en
  bewaakt worden (Grafana-dashboards + Prometheus-alerts): welke databron per grootheid leidend
  is, hoe onbetrouwbare/lege sensoren behandeld worden, en hoe panelen zich tot de tijdkiezer
  verhouden.

### Modified Capabilities
<!-- Geen bestaande spec onder openspec/specs/ dekt ATAG-monitoring; dit is net-nieuw. -->

## Impact

- **Affected files**:
  - `modules/monitoring/grafana/dashboards/torreiro/atag-boiler.json` (gas-queries, outlierfilter,
    panelen verwijderen)
  - `modules/monitoring/grafana/dashboards/torreiro/atag-thermal-dashboard.json` (outlierfilter,
    `$__range`, dood paneel verwijderen, titel "(24u)" opschonen)
  - `modules/monitoring/prometheus/alerts/atag-alerts.yml` (dode alert verwijderen)
- **Geen** wijziging aan de HA-integratie, de ATAG-API of de Prometheus-export; dit is dashboard-
  en alertconfiguratie.
- **Uitrol**: `nixos-rebuild switch --flake .#malandro` (herladen Grafana-dashboards +
  Prometheus-alertregels).
- **Buiten scope** (bewust niet in deze change): de m³/graaddag-vergelijking (vervolg, zinvol
  zodra het stookt en de gasmeting staat) en het verlagen van de stooklijn / max aanvoertemperatuur
  (ketel-/thermostaatinstelling, geen dashboardwerk).
