---
name: vikunja-afspraak
description: Maak een afspraak of taak met herinneringen aan in Vikunja (tasks.toorren.net) via de Vikunja-MCP. Gebruik dit bij elk verzoek om een afspraak, herinnering, deadline of to-do in Vikunja te zetten ("maak een afspraak", "zet in Vikunja", "herinner me aan", "1 week van tevoren een herinnering"), ook als er meerdere afspraken tegelijk of afspraken relatief aan elkaar ("1,5 week eerder") worden gevraagd.
---

# Afspraken maken in Vikunja

Herinneringen uit Vikunja komen via de webhook op malandro binnen als **Signal-bericht**. Het
bericht bevat titel, project, deadline, de beschrijving en een link. Alles wat de gebruiker op
het moment zelf moet weten (waar spullen liggen, wat mee te nemen, adres) hoort daarom in de
**beschrijving**.

## Gereedschap

Laad eerst de schema's (deferred tools):

```
ToolSearch  select:mcp__vikunja__tasks_create,mcp__vikunja__projects_list,mcp__vikunja__tasks_update,mcp__vikunja__tasks_delete
```

## Werkwijze

### 1. Gegevens verzamelen

| Gegeven      | Verplicht | Als het ontbreekt                                                     |
|--------------|-----------|-----------------------------------------------------------------------|
| Titel        | ja        | afleiden uit het verzoek, letterlijk overnemen wat de gebruiker noemt |
| Datum        | ja        | vragen                                                                |
| Tijd         | ja*       | **vragen**, zie hieronder                                             |
| Herinneringen | nee      | standaardblok: 1 maand, 1 week, 1 dag, 1 uur van tevoren              |
| Beschrijving | nee       | leeg laten; praktische details van de gebruiker hier zetten           |
| Project      | nee       | `Inbox`                                                               |

\* Zonder tijd valt de deadline op 00:00. Een herinnering van "1 uur van tevoren" gaat dan om
23:00 de avond ervoor af. Vraag daarom altijd naar de tijd als er herinneringen in uren zijn, of
als het om een afspraak met een vast tijdstip gaat. Alleen bij een echte "voor die dag af"-taak
zonder uur-herinneringen mag je zonder tijd verder; noem dat dan expliciet.

Stel alle ontbrekende vragen **in één keer**, niet één voor één.

### 2. Project bepalen

Roep `projects_list` aan en zoek het project op titel (default `Inbox`). Hardcodeer geen id.
Bestaat het genoemde project niet, vraag dan of het Inbox mag zijn.

### 3. Tijdzone en datum controleren

Vikunja wil een ISO-8601-tijd met offset. Europe/Amsterdam wisselt tussen `+02:00` (zomertijd)
en `+01:00` (wintertijd). Gok de offset niet, maar laat `date` hem bepalen, samen met de
weekdag:

```bash
date -d '2027-10-08 09:30' '+%a %F %R %z'    # → Fri 2027-10-08 09:30 +0200
```

Een relatieve datum ("1,5 week eerder", "de dag ervoor") reken je ook met `date -d` uit. Valt
die halverwege een dag of in een weekend, kies dan een redelijke werkdag op hetzelfde tijdstip
en **meld die keuze** in het antwoord.

### 4. Herinneringen

Gebruik **relatieve** herinneringen ten opzichte van de deadline. Verschuift de afspraak later,
dan schuiven de herinneringen vanzelf mee:

```json
"reminders": [
  {"relative_to": "due_date", "relative_period": -2592000},
  {"relative_to": "due_date", "relative_period": -604800},
  {"relative_to": "due_date", "relative_period": -86400},
  {"relative_to": "due_date", "relative_period": -3600}
]
```

| Periode          | Seconden   |
|------------------|------------|
| 1 maand (30 d)   | -2592000   |
| 2 weken          | -1209600   |
| 1 week           | -604800    |
| 3 dagen          | -259200    |
| 1 dag            | -86400     |
| 2 uur            | -7200      |
| 1 uur            | -3600      |
| 15 minuten       | -900       |
| op het moment zelf | 0        |

Vikunja rekent in seconden: "1 maand" is 30 dagen. Noem dat als het verschil ertoe doet.

Een herinnering op een vast tijdstip, los van de deadline, gaat met
`{"reminder": "2027-09-01T09:00:00+02:00"}`.

### 5. Aanmaken

```
tasks_create(project=<id>, title=..., due_date=..., reminders=[...],
             description=..., format="markdown")
```

Meerdere onafhankelijke afspraken maak je in parallelle aanroepen.

### 6. Controleren en melden

Lees de herinneringsmomenten uit het **antwoord** van de API (het veld `reminder` per
herinnering). Daar staan de tijden die Vikunja zelf heeft uitgerekend. Meld per afspraak:

- id (`#15`), titel, weekdag + datum + tijd
- een tabel met de herinneringsmomenten (weekdag, datum, tijd)
- eigen keuzes (gekozen dag bij een relatieve datum, 30-dagenmaand)
- herinneringen die al in het verleden liggen: die gaan niet meer af, meld dat

## Niet doen

- Geen testtaken laten staan. Maak je er een om de keten te testen, verwijder hem daarna met
  `tasks_delete` en meld dat.
- Geen `description` in HTML schrijven als je `format="markdown"` meegeeft.
- Geen afspraken met tijd 00:00 aanmaken omdat er geen tijd genoemd is (zie stap 1).
