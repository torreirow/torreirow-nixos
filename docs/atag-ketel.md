# ATAG One — ketelgedrag, pendelen en afstelling

**Aangemaakt:** 2026-10-22 · **Status:** stap 2 (`average`) actief sinds 2026-10-22 21:52, meten t/m ~28 okt

`temperatuurinvloed` wijzigt alleen **hoe** de ketel de aanvoertemperatuur kiest (stooklijn vs. puur
kamer); het tijdschema (preset `auto`, nacht 15 / ochtend 20,5 °C) blijft gewoon werken.

Werknotitie om het stookgedrag van de ATAG One te volgen en instellingen **één voor één** te
veranderen en te meten. Bron: Home Assistant op malandro (`climate.atag_one` + `sensor.atag_one_*`).

## Aanleiding: ochtend 22 okt 04:00–07:30

| Tijd        | Wat er gebeurde                                                              |
|-------------|------------------------------------------------------------------------------|
| 04:00–06:39 | Nachtstand 15 °C, brander uit. Kamer 20,6 → 20,2 °C (buiten 7,9 → 7,5 °C)    |
| 06:39       | Voorverwarmen start (setpoint nog 15 °C) voor het programma van 07:15        |
| 06:40–06:49 | Brander tot 48 %, CV-water 20 → 47 °C                                        |
| 06:56–07:17 | Aan/uit-cycli om de ~4–8 min (CV-water 37 ↔ 47 °C) = **pendelen**            |
| 07:15       | Setpoint → 20,5 °C; daarna continu stoken, kamer 20,9 °C om 07:28            |

Gas 06:39–07:28 ≈ 0,04 m³.

## Bevindingen

1. **Pendelen is structureel**, niet alleen deze ochtend: gemiddeld **~5 min per branderrun**
   (gezond is ≥ 10 min). Zie baseline hieronder.
2. **Nachtverlaging doet vrijwel niets**: het huis koelt in 3 uur maar ~0,5 °C af bij 8 °C buiten;
   de kamer komt nooit bij 15 °C. Levert alleen het voorverwarmen op.
3. **`sensor.atag_one_brander` is onbetrouwbaar**: bleef na 06:49 op 0 % terwijl gas liep en het
   CV-water opwarmde. Het Grafana-dashboard `modules/monitoring/grafana/dashboards/torreiro/atag-boiler.json`
   gebruikt deze sensor → toont "uit" terwijl de ketel brandt. Gebruik `gasverbruik`/`cv_water_temp`.
4. **Geen recorder-historie** voor `sensor.atag_effectief_doel`, `sensor.atag_doel_bron` en
   `sensor.atag_one_gas` (niet in `recorder.include`, zie `docs/homeassistant-data-retention.md`).

## Baseline (vóór wijzigingen)

Starts = overgangen `hvac_action` idle → heating van `climate.atag_one`. Benadering: de integratie
pollt per ~1–3 min, korte runs kunnen gemist of afgerond zijn.

| Datum      | Starts | Stookmin | Min/start | Buiten gem. |
|------------|-------:|---------:|----------:|------------:|
| 2026-10-15 |     12 |       60 |       5,0 |      15,0 °C |
| 2026-10-16 |      2 |       11 |       5,6 |      15,3 °C |
| 2026-10-17 |     19 |       97 |       5,1 |      11,9 °C |
| 2026-10-18 |     14 |       66 |       4,7 |       9,8 °C |
| 2026-10-19 |     24 |      152 |       6,3 |       8,7 °C |
| 2026-10-20 |     32 |      162 |       5,1 |       5,9 °C |
| 2026-10-21 |     26 |      133 |       5,1 |      10,8 °C |
| 2026-10-22 |     16 |      119 |       7,5 |       9,8 °C |

**Doel:** min/start omhoog (≥ 10), starts per dag omlaag, bij vergelijkbare buitentemperatuur.

## Huidige instellingen (2026-10-22)

| Instelling                          | Waarde            | Via HA instelbaar? |
|-------------------------------------|-------------------|--------------------|
| `select.atag_one_temperatuurinvloed`| `room_regulation` | ja (`off`/`less`/`average`/`more`/`room_regulation`) |
| `select.atag_one_isolatieniveau`    | `good`            | ja                 |
| `select.atag_one_gebouwgrootte`     | `medium`          | ja                 |
| `sensor.atag_one_max_boiler_temp`   | 60 °C             | **nee** (alleen sensor → ATAG-app/thermostaat) |
| Nachtstand / ochtend                | 15 °C / 20,5 °C om 07:15 | programma in ATAG |

## Aanbevelingen (in volgorde, één tegelijk, elk ≥ 5 dagen meten)

1. **Grafana:** brander-paneel baseren op `gasverbruik` i.p.v. `brander`.
2. **Weersafhankelijk stoken:** `temperatuurinvloed` `room_regulation` → `average`. Verwacht: lager
   en langer moduleren, minder starts.
3. **Max CV-temperatuur 60 → ~50 °C** (via app/thermostaat). Langere runs, lagere retour (nu ~46 °C),
   beter condenseren. Risico: trager opwarmen op koude dagen.
4. **Nachtstand 15 → ~18,5 °C** of ochtendprogramma later. Klein effect, lage prioriteit.

## Wijzigingslog

| Datum | Wijziging | Vorige waarde | Resultaat (min/start, starts/dag) |
|-------|-----------|---------------|-----------------------------------|
| 2026-10-22 21:52 | `temperatuurinvloed` → `average` (aanbeveling 2) | `room_regulation` (nooit eerder gewijzigd) | meten vanaf 23 okt t/m ~28 okt |

### Observaties `average`

- **2026-10-23 ochtend (04:00–07:30):** kamer 04:00 al 19,4 °C (22 okt: 20,6), voorverwarmen
  start 06:16 (22 okt: 06:39), eerste run 23 min, daarna 4 runs van 2–14 min (gem. ~10 min over
  5 starts). CV-water piekt 54–55 °C (22 okt: 47 °C). Kamer **20,5 °C om 07:30** (22 okt: 20,9) →
  comfort net gehaald, nog niet terug naar `room_regulation`; weekevaluatie 28 okt beslist.

## Opnieuw meten

Op malandro. Pas de datums aan; schrijft per dag starts, stookminuten en buitentemperatuur.

```bash
T=$(sudo cat /run/agenix/homeassistant-prometheus-token | tr -d '\n')
curl -s -H "Authorization: Bearer $T" \
  "http://127.0.0.1:8123/api/history/period/2026-10-15T00:00:00+02:00?end_time=2026-10-22T21:00:00%2B02:00&filter_entity_id=climate.atag_one,sensor.atag_one_buiten_temp" \
| python3 -I -c '
import json,sys
from collections import defaultdict
from datetime import datetime,timezone,timedelta
tz=timezone(timedelta(hours=2)); d={s[0]["entity_id"]:s for s in json.load(sys.stdin)}
t=lambda s: datetime.fromisoformat(s["last_changed"]).astimezone(tz)
st=defaultdict(int); mn=defaultdict(float); bt=defaultdict(list); prev=t0=None
for s in d.get("climate.atag_one",[]):
    a=s["attributes"].get("hvac_action")
    if a=="heating" and prev!="heating": st[t(s).date()]+=1; t0=t(s)
    if a!="heating" and prev=="heating" and t0: mn[t0.date()]+=(t(s)-t0).total_seconds()/60
    prev=a
for s in d.get("sensor.atag_one_buiten_temp",[]):
    try: bt[t(s).date()].append(float(s["state"]))
    except ValueError: pass
for k in sorted(set(st)|set(bt)):
    n=st.get(k,0); m=mn.get(k,0); b=bt[k]
    print(k, n, round(m), round(m/n,1) if n else "-", round(sum(b)/len(b),1) if b else "-")
'
```

Let op zomer-/wintertijd: na 25 okt is lokale tijd UTC+1 → `+02:00` wordt `+01:00` (ook in `tz`).
