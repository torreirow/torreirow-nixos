# Proposal

## Why

De frontmatter van het torrlinny-notitieboek is op 2026-09-25 met de hand genormaliseerd (12
bestanden, bean `nixos-zets`). Er is niets dat voorkomt dat die netheid weer wegzakt: de canonieke
regel staat alleen in een bean, en het detectiescript is een eenmalig fragment dat nergens draait.

Het gaat niet om smaak. De indexer van linny-mcp normaliseert zélf — `strings.ReplaceAll(
strings.ToLower(term), " ", "-")` — dus wat je schrijft is níét wat je terugkrijgt. Op de
Hugo-taxonomiezijbalk van `linny.toorren.net` verschijnt elke variant als een aparte regel met een
eigen telling, en dat is de enige plek waar je het ziet. Erger is het geval zonder frontmatter: zo'n
notitie belandt helemaal niet in de index en is daarmee onzichtbaar voor de agent — gemeten tijdens
de epic (117 records + `WARN malformed front matter`, de notitie zelf `SELECT count(*) = 0`).

Bovendien deugt het detectiescript uit de bean niet goed genoeg om te hergebruiken: het leest een
YAML-lijst (`tags: [frontmatter, refactor]`) als één string en meldt die ten onrechte als variant,
en het kent geen uitzonderingen, waardoor het zes bestanden aanwijst die per definitie geen
`customer` hebben — vijf `_index.md`-secties en `content/search.md`.

## What Changes

- Nieuw script `modules/linny-web-frontmatter/check-frontmatter.py`: toetst een Linny-corpus tegen
  de canonieke term-vorm en rapporteert afwijkingen met exitcode 1.
- **Lijstwaarden worden per element getoetst**, niet als één string — dat is het defect in het
  script uit de bean.
- Een expliciete **uitzonderingslijst** voor bestanden die geen `customer` horen te hebben
  (`**/_index.md`, `content/search.md`), zodat een schone run ook echt schoon is en niet gewend
  raakt aan ruis.
- Unittests (`check_frontmatter_test.py`) die zonder corpus en zonder netwerk draaien.
- Het script is **niet blokkerend** voor de bestaande `linny-web-build`: een notitieboek met een
  afwijking hoort nog steeds gebouwd en gepubliceerd te worden. Rapporteren, niet tegenhouden.

Niet in scope: de twee notities die nog geen `customer` hebben (`content/bedrock.md`,
`content/to-do-wk52.md`). Dat is een inhoudelijke keuze van de eigenaar, geen gereedschap, en het
blijft in bean `nixos-zets` staan.

## Capabilities

### New Capabilities
- `linny-frontmatter-guard`: het toetsen van een Linny-corpus op canonieke frontmatter-termen,
  ontbrekende verplichte velden en ontbrekende frontmatter.

### Modified Capabilities
- geen

## Impact

- Raakt geen draaiende dienst. Het script leest een checkout en schrijft niets.
- De canonieke regel wordt hier vastgelegd; wijkt de indexer van linny-mcp ooit af, dan moet dit
  script mee. Dat staat als waarschuwing in de code.
