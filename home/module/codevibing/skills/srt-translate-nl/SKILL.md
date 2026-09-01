---
name: srt-translate-nl
description: Vertaal SRT-ondertitelbestanden naar het Nederlands op B2-niveau, met Nederlandse equivalenten voor Engelse uitdrukkingen en behoud van de SRT-structuur. Gebruik dit bij elk verzoek om een .srt-bestand te vertalen, te ondertitelen of naar het Nederlands om te zetten.
---

# SRT vertalen naar het Nederlands

## Taalniveau

Schrijf op **B2-niveau Nederlands**: helder en toegankelijk voor een breed
publiek, zonder kinderlijk te worden. Concreet betekent dat:

- Korte tot middellange zinnen; splits lange Engelse bijzinconstructies op.
- Alledaagse woorden boven formele of academische synoniemen.
- Actieve vorm boven lijdende vorm waar dat natuurlijk klinkt.
- Vakjargon alleen als de spreker het ook gebruikt en het publiek het kent.

## Uitdrukkingen en idioom

Vertaal Engelse uitdrukkingen **niet letterlijk**. Zoek het Nederlandse
equivalent dat dezelfde lading heeft:

| Engels                                  | Nederlands                                              |
|-----------------------------------------|---------------------------------------------------------|
| crossing the Rubicon                    | de Rubicon oversteken / een punt van geen terugkeer passeren |
| shame on you                            | voor schut / schande over je                            |
| the enemy of my enemy is my friend      | de vijand van mijn vijand is mijn vriend                 |

Staat een uitdrukking hier niet bij, kies dan een Nederlandse zegswijze met
dezelfde betekenis. Bestaat die niet, parafraseer dan de bedoeling in gewoon
Nederlands — een letterlijke vertaling die nergens op slaat is altijd de
slechtste optie.

## Stopwoorden aan het zinsbegin

Vertaal Engelse stopwoorden aan het begin van een zin **niet**. Laat ze
staan of laat ze weg — vertaal ze niet naar "dus", "nou", "goed", enzovoort.
Dit geldt onder meer voor: *so*, *well*, *now*, *right*, *okay*, *you know*.

```
"So, let's look at verse three."   →  "Laten we naar vers drie kijken."
"Well, that's not quite true."     →  "Dat klopt niet helemaal."
```

Middenin een zin gelden de normale vertaalregels wél.

## Grammatica

Gebruik correcte Nederlandse zinsbouw — niet de Engelse woordvolgorde met
Nederlandse woorden. Let vooral op:

- Werkwoord op de tweede plaats in hoofdzinnen, achteraan in bijzinnen.
- `de`/`het` correct bij elk zelfstandig naamwoord.
- Geen Engelse bezitsconstructie (`Jan zijn boek` → `Jans boek` / `het boek van Jan`).

## SRT-formaat behouden

Het bestandsformaat moet **exact intact** blijven:

1. Blokvolgnummers ongewijzigd overnemen.
2. Timingregels (`00:01:23,456 --> 00:01:26,789`) letterlijk ongewijzigd laten.
3. Eén lege regel tussen blokken, geen lege regel aan het eind te veel.
4. Het aantal blokken in de uitvoer is gelijk aan dat in de invoer.
5. Regelafbrekingen binnen een blok blijven behouden (meestal 1-2 regels).

Als een Nederlandse zin langer wordt dan de Engelse, herformuleer korter in
plaats van het blok te laten uitdijen — ondertitels moeten leesbaar blijven
binnen hun tijdvak. Verplaats nooit tekst naar een ander blok.

## Uitvoerbestand

Schrijf het resultaat naar `[originele-naam].nl.srt` in dezelfde map:

```
vince-1sam-183.srt  →  vince-1sam-183.nl.srt
```

Overschrijf het originele bestand nooit.

## Werkwijze

Bij grote bestanden: vertaal in blokken van 50-100 ondertitels tegelijk en
schrijf ze weg, zodat het werk niet in één keer hoeft te passen. Controleer
na afloop dat het aantal blokken en alle timingregels overeenkomen met het
origineel:

```bash
grep -c ' --> ' origineel.srt origineel.nl.srt   # moet gelijk zijn
diff <(grep ' --> ' origineel.srt) <(grep ' --> ' origineel.nl.srt)  # moet leeg zijn
```
