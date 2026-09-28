# Ontwerp: frontmatter-controle voor een Linny-corpus

## Context

Zie `proposal.md` voor de aanleiding. Wat hier telt aan bestaande toestand:

- De canonieke regel is niet van ons. Hij komt uit linny-mcp
  (`internal/…`: `strings.ReplaceAll(strings.ToLower(term), " ", "-")`) en bepaalt wat de agent
  terugkrijgt. Onze controle moet die regel *volgen*, niet definiëren.
- Het corpus staat in een **andere, privé repo** (`torreirow/torrlinny`). Op malandro bestaan er
  twee werkmappen van: `/var/lib/torrlinny/checkout` voor de Hugo-build en
  `/var/lib/linny-mcp/corpus` voor de MCP-server. Op lobos staat de gewone werkkopie.
- De Hugo-build doet `reset --hard` + `clean -fdx` op zijn checkout. Wat daar geschreven wordt, is
  binnen drie minuten weg.

## Goals / Non-Goals

**Goals**

- Eén script dat op elke checkout van een Linny-corpus draait, zonder aannames over welke.
- Een schone run is écht leeg, zodat een melding iets betekent.

**Non-Goals**

- Zelf corrigeren. Een notitie bijwerken is een inhoudelijke keuze; deze controle stelt alleen vast.
- Onderdeel worden van `linny-web-build`. Een notitieboek met een schoonheidsfoutje hoort gewoon
  gepubliceerd te worden.
- Een oordeel over wélke `customer` bij een notitie past.

## Decisions

### 1. Frontmatter met de hand ontleden, geen YAML-afhankelijkheid

Het script leest het blok tussen de eerste twee `---`-regels en pakt alleen de sleutels die het kent
(`customer`, `doctype`, `type`, `project`, `tag`, `tags`, `owner`).

Alternatief was PyYAML. Verworpen omdat dit script juist óók moet werken op een corpus waarvan de
frontmatter stuk is — dat is een van de gevallen die het moet melden. Een YAML-parser werpt dan een
uitzondering en het onderscheid tussen "geen frontmatter" en "kapotte frontmatter" gaat verloren.
Bijkomend: geen extra dependency in een script dat op drie plekken kan draaien.

Prijs: lijstwaarden moeten we zelf herkennen. Dat is precies het defect in het script uit de bean.
Beide YAML-vormen tellen:

```yaml
tags: [frontmatter, refactor]     # inline
tags:                             # block
  - frontmatter
  - refactor
```

### 2. De uitzonderingslijst is een patroonlijst, geen "sla lege waarden over"

`**/_index.md` en `content/search.md` hebben geen eigen taxonomie — de eerste zijn
sectie-indexpagina's, de tweede is Hugo's zoekpagina (`type: "search"`). Zonder die lijst meldt de
controle zes bestanden die niets mankeren, en dan went men aan ruis.

De uitzondering geldt **alleen voor het verplichte veld**, niet voor de termvorm: staat er tóch een
taxonomie-term in zo'n bestand, dan moet die canoniek zijn. Anders zou de uitzondering een gat zijn
in plaats van een verfijning.

### 3. Corpuspad als argument, niet hardgecodeerd

Het script krijgt het pad mee (standaard de huidige map). Zo draait het op lobos in de werkkopie,
op malandro op beide werkmappen, en in een test op een tijdelijke map met geconstrueerde bestanden.

### 4. Exitcode 1 bij afwijkingen, maar géén koppeling aan de build

Zo is het bruikbaar in een pre-commit, een handmatige controle of later een timer, zonder dat het
nu al iets kan tegenhouden. De keuze om het ergens verplicht te maken blijft een aparte beslissing.

### 5. De regel staat op één plek, met een waarschuwing

De normalisatie staat als één functie bovenaan het script, met de verwijzing naar linny-mcp erbij.
Wijkt upstream ooit af, dan is dit de plek die mee moet — en dan is het een gerichte wijziging in
plaats van een zoektocht.

## Risks / Trade-offs

- **Het script kan uit de pas lopen met linny-mcp.** Er is geen mechanisme dat dat opmerkt. De
  waarschuwing in de code is de enige rem; een test tegen de echte indexer zou beter zijn maar
  vereist het Go-pakket in de testomgeving.
- **Handmatig ontleden mist gevallen die YAML wél kent** (ankers, meerregelige waarden, quoting-
  varianten). Voor een notitieboek met platte scalars en korte lijsten is dat acceptabel; het
  script moet bij twijfel eerder mélden dan stilzwijgend accepteren.
- **Niet blokkerend betekent dat het genegeerd kan worden.** Dat is hier bewust: de kosten van een
  gemiste normalisatie zijn een dubbele regel in een zijbalk, niet een storing.

## Migration Plan

Geen. Het script leest alleen; er is geen bestaande toestand om over te zetten. De eerste run op het
echte corpus hoort twee meldingen te geven — `content/bedrock.md` en `content/to-do-wk52.md` zonder
`customer` — en die blijven staan tot de eigenaar ze invult (bean `nixos-zets`).

## Open Questions

- Moet de controle later aan iets vast? Een pre-commit in torrlinny ligt het meest voor de hand,
  maar die repo heeft nu geen hooks. Bewust uitgesteld tot het script zich bewezen heeft.
