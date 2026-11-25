# ATAG One — ketelgedrag, pendelen en afstelling

**Aangemaakt:** 2026-10-22 · **Status:** bij koud weer (≤ 1 °C) haalt de ketel het doel ruim (24 nov: 37,9 min/start). Het pendelen in het schouderseizoen is geen ketelfout maar het gevolg van een warmtevraag (~1,2 kW) die ver onder het minimumvermogen van de ketel ligt. Actief sinds 25 nov: dagblok ma–vr 16,0 → 18,5 °C en `max_preheat` 60 → 30 min; meten t/m 30 nov (`~/scripts/atag-eval.sh 2026-11-25 2026-11-30`).

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

## Huidige instellingen (2026-11-25)

| Instelling                          | Waarde            | Via HA instelbaar? |
|-------------------------------------|-------------------|--------------------|
| `select.atag_one_temperatuurinvloed`| `average`         | ja (`off`/`less`/`average`/`more`/`room_regulation`) |
| `select.atag_one_isolatieniveau`    | `good`            | ja                 |
| `select.atag_one_gebouwgrootte`     | `medium`          | ja                 |
| `select.atag_one_verwarmingstype`   | `radiator_underfloor` (was `radiator`, 17 nov) | ja |
| `sensor.atag_one_max_boiler_temp`   | 50 °C             | **nee** (API `ch_temp_max`; CV-pieken daarboven zijn tapwater, zie 18–24 nov) |
| `max_preheat`                       | 30 min (was 60, 25 nov) | **nee** in HA; wel via de ATAG-API |
| Weekprogramma                       | zie "Weekprogramma" hieronder | **nee** in HA; wel via de ATAG-API |
| `switch.atag_one_zomer_eco_mode`    | aan               | ja                 |
| `number.atag_one_zomer_eco_temp`    | 18 °C (was 20)    | ja (10–25 °C)      |

**Zomer eco:** boven de drempel (buitentemperatuur) stookt de ketel niet voor CV; tapwater blijft
werken. Niet zichtbaar in de ATAG-app. De integratie `atagone` noemde de drempel ten onrechte
`number.atag_one_temp_vakantieperiode` (unique_id eindigt op `summer_eco_temp`); hernoemd
2026-11-03. De echte vakantietemperatuur is `number.atag_one_vakantie_temp`.

## Weekprogramma (2026-11-25, via de ATAG-API)

| Dagen  | Blokken (start @ temperatuur; elk blok loopt tot de volgende start)             |
|--------|----------------------------------------------------------------------------------|
| ma–wo  | 06:30 @20,5 · 07:30 @18,5 · 16:30 @20,5 · 21:45 @17 · 23:30 @16                  |
| do–vr  | 07:15 @20,5 · 09:00 @18,5 · 16:30 @20,5 · 21:45 @17 · 23:30 @16                  |
| za     | 00:00 @16 · 08:00 @20,0 · 21:45 @17                                              |
| zo     | 00:00 @16 · 08:00 @20,0 · 09:40 @17 · 12:00 @20,0 · 21:45 @17                    |

Voor ma–vr geldt tussen 00:00 en het eerste blok de basis van 15 °C.

**Let op: de API levert de dagen in de volgorde ma, di, wo, do, vr, za, zo** — niet zo…za. Dat is op
25 nov 2026 gecontroleerd tegen de werkelijke blokwissels: woensdag gebruikte het 06:30-blok en
zondag het 08:00-blok met de dip van 09:40–12:00 @17. Eerder stonden de labels in
`~/scripts/atag-schedule.sh` en in dit document één dag verschoven; de wijziging van 17 nov
(05:45 → 06:30) trof daardoor ma/di/**wo** en niet zo.

Het voorverwarmen begint `max_preheat` minuten vóór het eerste blok: gemeten 59–60 min bij
`max_preheat 60` (05:31 voor 06:30, 06:16 voor 07:15, 07:01 voor 08:00). Op 25 nov is dat naar
30 min gezet.

### De ATAG-API (poort 10000)

De thermostaat heeft een lokale JSON-API op `http://192.168.2.1:10000`. Home Assistant gebruikt die
via de integratie `atagone`, maar die kan alleen sensoren en `select`/`number`/`switch` zetten —
het weekprogramma niet. Direct op de API kan dat wel:

```bash
# lezen (info 127 = alle secties)
curl -s -X POST http://192.168.2.1:10000/retrieve -H 'Content-Type: application/json' \
  -d '{"retrieve_message":{"seqnr":0,"account_auth":{"user_account":"","mac_address":"01:23:45:67:89:01"},"info":127}'
# schrijven: /update met dezelfde account_auth en de gewijzigde sectie, bijv. schedules.ch_schedule
```

`schedules.ch_schedule` bestaat uit `base_temp` plus `entries`: 7 dagen (zo=0 … za=6), elk een lijst
`[start_min, eind_min, temperatuur]` met minuten na middernacht (`390` = 06:30). `~/scripts/atag-schedule.sh`
print het huidige programma en de belangrijkste configuratie in leesbare vorm. Altijd eerst de
respons opslaan vóór een wijziging: de thermostaat kent geen ongedaan maken.

## Aanbevelingen (in volgorde, één tegelijk, elk ≥ 5 dagen meten)

1. ~~**Grafana:** brander-paneel baseren op `gasverbruik` i.p.v. `brander`.~~ **Gedaan 2026-10-24:**
   gauge "Gasdebiet ketel" (m³/u, `sensor.atag_one_gasverbruik`) en timeseries "Brander Activiteit
   (gasdebiet)" met gasdebiet plus `hvac_action` heating als 0/1-band. Let op: gasdebiet omvat ook
   warm water, dus > 0 zonder warmtevraag = tapwater.
2. **Weersafhankelijk stoken:** `temperatuurinvloed` `room_regulation` → `average`. Verwacht: lager
   en langer moduleren, minder starts.
3. **Max CV-temperatuur 60 → ~50 °C** (via app/thermostaat). Langere runs, lagere retour (nu ~46 °C),
   beter condenseren. Risico: trager opwarmen op koude dagen.
4. **Nachtstand 15 → ~18,5 °C** of ochtendprogramma later. Klein effect, lage prioriteit.

**Stand 2026-11-25:** 1–3 zijn uitgevoerd. Wat overblijft is het tapwater (zie "Warm water") en de
vraag aan de installateur naar het minimumvermogen en de anti-pendeltijd — de enige knoppen die de
runlengte bij kleine warmtevraag echt veranderen.

## Wijzigingslog

| Datum | Wijziging | Vorige waarde | Resultaat (min/start, starts/dag) |
|-------|-----------|---------------|-----------------------------------|
| 2026-10-22 21:52 | `temperatuurinvloed` → `average` (aanbeveling 2) | `room_regulation` (nooit eerder gewijzigd) | **geen verbetering:** 5,3 min/start (gelijk), 27,4 starts/dag (was 23,0) |
| 2026-10-28 ~19:20 | Max CV-aanvoertemperatuur 60 → 50 °C op de ketel zelf (E325EC, installateursparameter; aanbeveling 3). `average` blijft staan. CV bijgevuld 1,4 → 2,0 bar | 60 °C | **runs niet langer:** 5,3 min/start (gelijk), 19,8 starts/dag (was 23,0 baseline, 27,4 `average`), 105 stookmin/dag (was 122). HA-sensor `max_boiler_temp` toonde pas na herstart van HA (reboot malandro 28 okt 19:35) 50 °C: de integratie leest deze waarde alleen bij opstarten |
| 2026-11-17 11:54 | `verwarmingstype` `radiator` → `radiator_underfloor` (lagere stooklijn, betere condensatie). API: `ch_heating_type` 3 → 4 | `radiator` | **−12 % gas** bij gelijk buitenweer (6,62 vs 7,55 m³/dag), aanvoer 5 K lager; min/start onveranderd (8,9) |
| 2026-11-17 13:05 | Ochtendblok ma/di/wo 05:45 → 06:30 (voorverwarmen begon om 04:46). Einde 07:30 blijft. *NB: destijds als zo/ma/di geadministreerd; de API-dagvolgorde is ma…zo.* | 05:45 | voorverwarmen begint nu 59 min vóór het blok |
| 2026-11-25 15:10 | Dagblok ma/di/wo (07:30–16:30) en do/vr (09:00–16:30) 16,0 → 18,5 °C. API: `schedules.ch_schedule` entries 0–4 | 16,0 °C | meten t/m 30 nov |
| 2026-11-25 15:10 | `max_preheat` 60 → 30 min. API: `configuration.max_preheat` | 60 | nachtstart 05:31 → ~06:00, meten t/m 30 nov |
| 2026-11-03 11:17 | Zomer-eco-drempel 20 → 18 °C (goed geïsoleerd huis: boven 18 °C buiten geen warmtevraag, alleen korte runs). Geen effect in de winter | 20 °C | pas te zien in lente/herfst |

### Observaties `average`

- **2026-10-23 ochtend (04:00–07:30):** kamer 04:00 al 19,4 °C (22 okt: 20,6), voorverwarmen
  start 06:16 (22 okt: 06:39), eerste run 23 min, daarna 4 runs van 2–14 min (gem. ~10 min over
  5 starts). CV-water piekt 54–55 °C (22 okt: 47 °C). Kamer **20,5 °C om 07:30** (22 okt: 20,9) →
  comfort net gehaald, nog niet terug naar `room_regulation`; weekevaluatie 28 okt beslist.

### Weekevaluatie `average` (2026-10-28)

Vergelijking op dagen met vergelijkbare buitentemperatuur (15–16 okt waren te mild en vallen af).
Gemeten met het script onder "Opnieuw meten" (tijdzone via `zoneinfo`, dus zomer-/wintertijd-proof).

| Periode                             | Starts/dag | Stookmin/dag | Min/start | Buiten gem. |
|-------------------------------------|-----------:|-------------:|----------:|------------:|
| Baseline `room_regulation` 17–21 okt |       23,0 |          122 |       5,3 |     10,5 °C |
| `average` 23–27 okt                  |       27,4 |          144 |       5,3 |     11,2 °C |

Per dag `average`: 23 okt 36 starts / 5,8 min, 24 okt 16 / 4,9, 25 okt 26 / 6,0, 26 okt 31 / 4,1,
27 okt 28 / 5,5. CV-water max 52–56 °C, retour max 43–47 °C (gelijk aan baseline).

**Conclusie:** `average` lost het pendelen niet op. Runs blijven ~5 min, er zijn eerder meer starts
dan minder, bij iets milder weer. De stooklijn bepaalt blijkbaar niet de runlengte; vermoedelijk is
het minimale vermogen van de ketel groter dan de warmtevraag, zodat hij snel zijn doel haalt en
afslaat. Volgende stap is aanbeveling 3 (max CV-temperatuur omlaag).

### Evaluatie max CV 50 °C (2026-11-03)

Gemeten met `~/scripts/atag-eval.sh 2026-10-29 2026-11-02`.

| Periode                              | Starts/dag | Stookmin/dag | Min/start | Buiten gem. |
|--------------------------------------|-----------:|-------------:|----------:|------------:|
| Baseline `room_regulation` 17–21 okt |       23,0 |          122 |       5,3 |     10,5 °C |
| `average` 23–27 okt                  |       27,4 |          144 |       5,3 |     11,2 °C |
| + max CV 50 °C 29 okt–2 nov          |       19,8 |          105 |       5,3 |     10,3 °C |

Per dag: 29 okt 15 starts / 4,9 min, 30 okt 29 / 5,0, 31 okt 11 / 5,2, 1 nov 16 / 5,9,
2 nov 28 / 5,5. Runs ≥ 10 min: 2–6 per dag. CV-water max 52,5–56,2 °C, retour max 44,5–46,2 °C.

**Conclusie:** minder starts (−14 % t.o.v. baseline) en minder stookminuten (−14 %) bij vrijwel
hetzelfde buitenweer, maar de runlengte blijft 5,3 min: het pendelen zelf is niet opgelost. Het
doel ≥ 10 min/start is niet gehaald. Opvallend: CV-water piekt nog boven 50 °C. Vermoedelijk is dat
warm tapwater (combiketel, zelfde sensor) en niet de CV-aanvoer; op 25 nov bevestigd (zie
"Evaluatie 18–24 nov").
Max CV 50 °C blijft staan. De oorzaak lijkt het minimale vermogen van de ketel, dat groter is dan de
warmtevraag; instellingen in HA veranderen daar niets aan. Opties voor de volgende stap:
aanbeveling 4 (nachtstand), of bij de installateur vragen naar minimaal vermogen en
anti-pendeltijd (installateursparameters).

### Evaluatie koude week (2026-11-17, 11–17 nov)

`~/scripts/atag-eval.sh 2026-11-11 2026-11-17`:

| Datum  | Starts | Stookmin | Min/start | Runs < 5 min | Buiten | Eerste start |
|--------|-------:|---------:|----------:|-------------:|-------:|-------------:|
| 11 nov |     52 |      456 |       8,8 |           17 |   3,9° |        04:46 |
| 12 nov |     17 |      464 |      27,3 |            1 |   5,8° |        06:16 |
| 13 nov |     19 |      389 |      20,5 |            8 |   6,4° |        06:16 |
| 14 nov |     33 |      387 |      11,7 |            8 |   4,3° |        07:01 |
| 15 nov |     32 |      431 |      13,5 |           14 |   4,7° |        07:01 |
| 16 nov |     36 |      358 |       9,9 |            8 |   4,8° |        04:47 |
| 17 nov |     13 |      182 |      14,0 |            0 |   2,6° |        04:47 |
| **Gem.** | **28,9** | **381** | **13,2** |    8/dag | 4,7° | |

**Conclusie:** bij echte warmtevraag brandt de ketel lang genoeg (doel ≥ 10 min gehaald). Het
pendelen van oktober is een schouderseizoensprobleem: kleine warmtevraag, dus korte runs. Slechte
dagen (11 en 15 nov) ontstaan door setpointwissels binnen een paar uur, niet door de ketel.

**De 50 °C-grens: opgelost op 25 nov.** `configuration.ch_temp_max` staat op 50,0 terwijl het
CV-water tot 57–60 °C kwam. De CV-pieken vallen samen met tapwaterbedrijf: op 22 nov 07:00–07:19
loopt `cv_water_temp` naar 58,6 °C terwijl `dhw_water_temp` van 20,8 → 49,8 °C stijgt. De
CV-sensor zit in hetzelfde leidingcircuit als de warmwaterwisselaar. Op CV wordt de 50 °C dus wél
gerespecteerd; de uitschieters zijn warm water.

**13 nov 21:04–21:09:** het setpoint sprong ±20 keer tussen 13,5 en 26,5 °C. Dat was handmatig
gedoe in de ATAG-app (bevestigd door de gebruiker), geen fout in HA of de ketel. Zo'n reeks
setpointwissels kost extra starts; niet nodig om te repareren.

### Evaluatie 18–24 nov (kouder, met `radiator_underfloor`)

`~/scripts/atag-eval.sh 2026-11-18 2026-11-24`. Gemiddeld buiten 4,7 °C — gelijk aan 11–17 nov,
dus goed vergelijkbaar. Gas uit `sensor.gas_meter_gasverbruik` (de echte meter, niet
`sensor.atag_one_gas`).

| Datum  | Starts | Stookmin | Min/start | Buiten | Gas (m³) |
|--------|-------:|---------:|----------:|-------:|---------:|
| 18 wo  |     57 |      322 |       5,7 |   9,0° |     6,00 |
| 19 do  |     43 |      266 |       6,2 |   7,8° |     5,20 |
| 20 vr  |     36 |      368 |      10,2 |   4,5° |     6,42 |
| 21 za  |     19 |      162 |       8,5 |   4,9° |     4,06 |
| 22 zo  |     52 |      362 |       7,0 |   3,9° |     6,12 |
| 23 ma  |     56 |      503 |       9,0 |   2,5° |     9,74 |
| 24 di  |     12 |      455 |  **37,9** |   0,4° |     8,80 |
| **Gem.** | **39,3** | **348** | **8,9** | **4,7°** | **6,62** |

| Periode                           | Starts/dag | Min/start | Gas/dag         |
|-----------------------------------|-----------:|----------:|-----------------|
| 11–17 nov (`radiator`)            |       28,9 |      13,2 | 7,55 m³         |
| 18–24 nov (`radiator_underfloor`) |       39,3 |       8,9 | 6,62 m³ (−12 %) |

**Conclusie:** het gasverbruik is 12 % lager bij hetzelfde gemiddelde buitenweer. De stooklijn is
duidelijk lager: CV-aanvoer tijdens verwarmen mediaan 48,6–55,4 °C vóór, 42,0–49,5 °C erna;
retour 40–45 → 33–41 °C. De retour zat met ~37 °C al onder het dauwpunt, dus de winst komt vooral
van lagere watertemperaturen en minder stilstandsverlies, niet van spectaculair betere condensatie.

**Het aantal starts steeg, maar niet door de ketel.** Van de 277 runs vielen er 96 in een periode
waarin het setpoint handmatig van 16,0 naar 19,5–20,5 °C was gezet; de kamer bleef daar op hangen.
De runlengte hangt vrijwel volledig samen met hoe ver de kamer van het setpoint zit:

| Kamer − setpoint bij start | Runs | Mediaan |
|----------------------------|-----:|--------:|
| meer dan 0,5 °C onder      |   31 | 10,2 min |
| 0,5–1,5 °C onder           |   24 |  9,7 min |
| tussen −0,5 en +0,5 °C     |  221 | **5,1 min** |

Het huis vraagt bij 2 °C buiten maar ~1,2 kW (CV-gas 1,5–4,4 m³/dag), terwijl de ketel niet lager
kan dan ~5 kW. Temperatuur vasthouden op het setpoint geeft dus per definitie runs van 4–6 min. Bij
echte kou verdwijnt het probleem: 24 nov (0,4°) 37,9 min/start met één run van 99 min. Dat is
precies het gewenste gedrag en het bevestigt dat het pendulum een schouderseizoensverschijnsel is.

**Comfort:** het dagblok van 16,0 °C liet de kamer op koude dagen naar 17,4–17,6 °C zakken, waarna
handmatig naar 19,5 °C werd gezet (23 nov 15:29 → 31 min, 24 nov 16:01 → 99 min). Daarom is op
25 nov het dagblok naar 18,5 °C gezet.

### Warm water (openstaand punt)

Ongeveer de helft van het gas gaat naar tapwater: met een schatting op basis van stijgend
`dhw_water_temp` tijdens branden kwam dat op 2,1–3,8 m³/dag. `dhw_status` wisselt dagelijks om
08:00/11:00 en 17:00/22:00 tussen 13 en 45 — dat zijn vaste comfortvensters die niet in
`dhw_schedule` staan (die geeft 45 in de blokken 00:00–06:45, 10:30–19:00 en 21:30–24:00).
`control.dhw_temp_setp` staat op 55 °C terwijl het schema 45 °C zegt.

Te doen: in de ATAG-app controleren of een warmwater-comfortprogramma met die twee vensters aan
staat, daarna `dhw_temp_setp` 55 → 50 °C via de API (`control`) en ≥ 5 dagen gas meten.
Legionella staat al aan (`dhw_legion_enabled 1`, zondag 03:15), dus 50 °C is veilig.

## Opnieuw meten

Op malandro: `~/scripts/atag-eval.sh [VAN] [TOT]` (standaard: laatste 7 dagen). Geeft per dag
starts, stookminuten, min/start, runs ≥ 10 min, buitentemperatuur en het CV-/retourmaximum. Het
script gebruikt `zoneinfo`, dus zomer-/wintertijd is geen probleem.

Gas per dag uit `sensor.gas_meter_gasverbruik` (de echte meter). `sensor.atag_one_gas` zit niet in
de recorder en `sensor.atag_one_gasverbruik` is een momentane schatting van de ketel zelf.
