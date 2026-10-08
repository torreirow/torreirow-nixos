# Design

## Context

Zie proposal.md — Why. De dashboards zijn declaratief: JSON in
`modules/monitoring/grafana/dashboards/torreiro/` en alertregels in
`modules/monitoring/prometheus/alerts/atag-alerts.yml`, uitgerold via
`nixos-rebuild switch --flake .#malandro`. Alle bevindingen zijn live geverifieerd op malandro via
Prometheus (14-daags venster, 2026-10-08):

| grootheid | entity | 14d-meting | oordeel |
|---------------------------|-------------------------------------|--------------|------------------------|
| boiler-gasschatting       | `sensor.atag_one_gas`               | +1,0 m³      | ~11× te laag, kapot    |
| P1/DSMR-huisgasmeter      | `sensor.gas_meter_gasverbruik`      | +11,5 m³     | correct                |
| branduren                 | `sensor.atag_one_branduren`         | +9,55 h      | leidend voor brandtijd |
| branderstarts             | `sensor.atag_one_lumc_brander_starts` | max 0      | structureel leeg       |
| warmwaterdoorstroming     | `sensor.atag_one_dhw_flow_rate`     | max 0        | structureel leeg       |
| opwarmtijd                | `sensor.atag_one_cv_tijd_naar_temp` | max 0        | structureel leeg       |
| brander-percentage        | `sensor.atag_one_brander`           | max 96       | werkt, behouden        |
| buitentemp                | `sensor.atag_one_buiten_temp`       | raw min −100 / filter −40 → 8,9 | outlier |
| CV-retour                 | `sensor.atag_one_cv_retour_temp`    | 20,1–45,6 °C | echte, onafhankelijke meting |
| warmhoud/wisselaar        | `sensor.atag_one_boiler_retour_temp`| 23–59,5 °C (zaagtand) | NIET de CV-retour; warmhoudtemp, nuttig |
| DHW-waterdruk             | `sensor.atag_one_dhw_waterdruk`     | max 0        | niet ondersteund — dood |
| boiler-capaciteit         | `sensor.atag_one_boiler_capaciteit` | max 0        | niet ondersteund (combi) — dood |
| CV-aanvoersetpoint        | `sensor.atag_one_setpoint_hotwater` | 0–42,2 °C    | misleidende naam; CV-setpoint, nuttig |
| kamertemp                 | `sensor.atag_one_kamer_temp`        | 21,1 °C      | kalibratiepaneel       |

Belangrijk: een `grep` over de repo-dashboards laat zien dat `boiler_retour_temp`, `dhw_waterdruk`,
`setpoint_hotwater` en `boiler_capaciteit` in géén enkel repo-Grafana-paneel voorkomen — alleen
`cv_retour_temp` wordt gebruikt (`atag-boiler.json`). Er zijn dus geen bestaande panelen te
verwijderen voor die sensoren; de spec legt ze als guard vast zodat ze ook niet alsnog insluipen.
Als zulke panelen ergens zichtbaar zijn, staan die in een HA-Lovelace-dashboard (buiten deze change).

Alle metrics dragen in Prometheus de naam `homeassistant_sensor_gas_mu0xb3` (gas),
`homeassistant_sensor_temperature_celsius` (temperaturen), `homeassistant_sensor_duration_h`
(branduren), `homeassistant_sensor_unit_percent` (percentage), `homeassistant_sensor_state`
(overige), met het onderscheid in het `entity`-label.

## Goals / Non-Goals

**Goals:**
- Gas-panelen op de fysieke P1-meter.
- Elke buitentemp-query robuust tegen bogus waarden (`> -40`).
- Alleen panelen/alerts die een reëel signaal hebben.
- Brandtijd uit de teller; tijdgebonden statistiek volgt de tijdkiezer.
- Rendementsindicatie uitsluitend op retourtemperatuur.

**Non-Goals:**
- De `sensor.atag_one_gas`-schatting kalibreren of herschalen (we vervangen hem, niet repareren).
- De structureel lege sensoren alsnog aan de praat krijgen (dat zit in de ketel/API, niet in het
  dashboard).
- De m³/graaddag-vergelijking bouwen (vervolg, apart) en het verlagen van de stooklijn / max
  aanvoertemperatuur (ketelinstelling, geen dashboardwerk).

## Decisions

**D1 — Gas: vervangen door de P1-meter, niet herschalen.**
De boiler-schatting is ~11× te laag; een vaste schaalfactor zou gokwerk zijn en breekt zodra de
ketel moduleert. De P1-meter is een echte, geijkte teller. Alternatief (schaalfactor op
`atag_one_gas`) verworpen: fragiel en niet verifieerbaar. Kanttekening: de P1-meter is het hele
huis (CV + koken); de kook-basislast is klein en verwaarloosbaar in het stookseizoen, maar wordt
genoemd met het oog op de m³/graaddag-vervolgstap.

**D2 — Outlierfilter als selector-conditie `> -40`.**
In PromQL filtert `metric > -40` de reeks op waarde; bogus metingen vallen weg vóór aggregatie.
Toegepast op alle vijf buitentemp-queries (gauge, correlatie-as, temperatuur-timeseries,
gemiddelde-buitentemp, thermal-tracking). Grens −40 °C is ruim onder elke reële Nederlandse
buitentemperatuur en ruim boven de −100-bogus. Alternatief (`clamp_min`) verworpen: dat vervangt
de outlier door −40 i.p.v. hem te verwijderen, wat min/gemiddelde nog steeds vertekent.

**D3 — Dode panelen/alert verwijderen i.p.v. verbergen.**
De drie sensoren zijn over 14 dagen constant 0; verbergen laat dode query's in de JSON staan.
Verwijderen: `Brander Starts`, `Opwarmtijd Kamer`, `Warm Water Flow Rate` (atag-boiler.json) en
`Brander Cycling Efficiency` (atag-thermal-dashboard.json). Alert `ATAGBurnerCyclingExcessive`
(`increase(lumc_brander_starts[1h]) > 10`) kan nooit vuren en gaat weg. De overige ATAG-alerts
(waterdruk, watertemperatuur, sensor-beschikbaarheid, integratie-down, gas-spike, DHW-temp) blijven.

**D4 — `$__range` voor tijdgebonden statistiek.**
Comfort/Accuracy/Stability op het Thermal-dashboard hardcoden `[24h]`/`[24h:5m]`. Vervangen door
`$__range` zodat ze het tijdbereik volgen. Paneel 1 "Temperatuur Tracking (24u)" hardcodeert
niets (instant query, volgt de kiezer al) — alleen de misleidende "(24u)" uit de titel. Het
"Afgelopen 24 uur"-gasstat in gas-consumption.json blijft `[24h]`: daar is een vast venster bedoeld.

**D5 — Rendement op retour alleen.**
`cv_retour_temp` is een echte meting (14d: 20,1–45,6 °C, max aanvoer−retour-delta 16 °C). Lage
retour = condenserend = goed rendement; dat is een directe, begrijpelijke maat. Het bestaande
delta-paneel `CV Temperatuur Delta (Efficiency Indicator)` (aanvoer − retour) wordt verwijderd. De
retour-timeseries en de condensatie-indicator-gauge (beide al op retour) blijven. `boiler_retour_temp`
wordt bewust gemeden als rendementsbron: dat is níét de CV-retour maar de warmhoud-/warmtewisselaar-
temperatuur (zaagtand 47–55 °C 's nachts, correleert 0,66 met het warm water terwijl het CV-water op
kamertemperatuur blijft). Het is echte, nuttige data — alleen een andere grootheid dan de CV-retour.

**D6 — Condensatiegrens 55 °C: drempellijn + alert.**
Natuurlijk gas condenseert zolang de retour onder ~55–57 °C blijft. We zetten een drempellijn op
55 °C op het retour-paneel en voegen een alert `ATAGReturnTempNotCondensing` toe
(`cv_retour_temp > 55` met een `for:`-venster). Nu onschadelijk (retour-max is 45,6 → vuurt niet),
maar wordt zinvol na de overstap naar kamergeregeld stoken (room_regulation) — die overstap zelf is
een ketelinstelling en valt buiten deze change. Alternatief (alleen een drempellijn, geen alert)
verworpen: de alert is declaratief en kost niets zolang hij niet vuurt.

**D7 — Kalibratiepaneel kamer − buiten.**
De ATAG-buitensensor hangt tijdelijk binnen voor kalibratie. Een timeseries van
`kamer_temp − buiten_temp` (met `> -40` op de buiten-term) maakt de afwijking volgbaar: een
stabiel verschil is de offset, richting 0 betekent gelijke omgeving. Nieuw paneel op
`atag-boiler.json` of het thermal-dashboard; databron is twee werkende sensoren (kamer 21,1 /
buiten 13,3 nu).

## Risks / Trade-offs

- **P1-meter bevat kook-/overig gas** → voor zuivere CV-analyse (m³/graaddag) later eventueel een
  basislast aftrekken; voor de huidige panelen verwaarloosbaar en hoe dan ook correcter dan de
  kapotte schatting.
- **Paneel-ids hergebruikt in atag-boiler.json** (ids 11/12/13 bestaan zowel als row als als stat)
  → bij het verwijderen van panelen op id letten dat het juiste paneel (de stat, niet de row)
  sneuvelt; verwijder op titel + type, niet blind op id.
- **Structureel lege sensoren kunnen ooit tóch data geven** (firmware/integratie-update) → dan is
  een nieuw paneel een bewuste, kleine toevoeging; we verliezen niets door ze nu te schrappen.
- **Dashboard-JSON is handmatig bewerkt** → na de wijziging visueel controleren in Grafana dat de
  panelen laden zonder parse-/query-fouten, naast de rebuild.

## Migration Plan

1. JSON- en alert-wijzigingen doorvoeren in de drie bestanden.
2. `nixos-rebuild switch --flake .#malandro` → Grafana herlaadt de dashboards, Prometheus de
   alertregels.
3. Verifiëren: gas-panelen tonen ~1 m³/h orde; buitentemp-min is plausibel; de vier dode panelen en
   de dode alert zijn weg; de (24u)-panelen volgen een gewijzigd tijdbereik; de rendementsindicatie
   staat op retour.
4. Rollback: `nixos-rebuild switch` naar de vorige generatie (dashboards/alerts zijn declaratief).
