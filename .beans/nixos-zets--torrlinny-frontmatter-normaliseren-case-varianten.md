---
# nixos-zets
title: torrlinny-frontmatter normaliseren (case-varianten + ontbrekende customer)
status: in-progress
type: task
priority: normal
created_at: 2026-09-25T07:43:48Z
updated_at: 2026-09-25T11:34:09Z
parent: nixos-m0vn
---

**Let op: dit speelt zich af in een ANDERE git-repo** — `torreirow/torrlinny`
(lokaal `/home/wtoorren/data/git/torreirow/torrlinny`), niet in torreirow-nixos.
Die repo is privé en heeft openspec maar geen beans; het werk wordt hier bijgehouden,
de wijzigingen landen daar. Geen OpenSpec-change nodig — een commit in het notitieboek volstaat.

Frontmatter gelijktrekken zodat er geen uitzonderingen meer zijn.

## De regel
Canonieke vorm = precies wat de linny-mcp-indexer doet:

    strings.ReplaceAll(strings.ToLower(term), " ", "-")

dus **alles lowercase, spaties worden dashes**. Daarmee is wat je schrijft ook wat je terugkrijgt.

## Omvang (gemeten 2026-09-25, 122 notities in `content/`)
- 7 notities met een case-variant, verdeeld over de velden `customer`, `project` en `owner`
- 8 notities zonder `customer`
- 1 notitie zonder enige frontmatter
- 2 termen met een spatie in `project` (worden nu stil tot een dash-vorm geïndexeerd)

De concrete waarden staan bewust niet in deze bean: torreirow-nixos is een **publieke** repo en de
taxonomie bevat klant- en projectnamen. Draai het detectiescript hieronder in de torrlinny-checkout
om de actuele lijst te krijgen.

## Gemeten tijdens de epic-uitvoering (2026-09-25)

`lindexer build` op het echte corpus: **117 records** geindexeerd, met

    WARN malformed front matter: <notitie> (no front matter)

Die notitie staat daarna **niet** in de index (`SELECT count(*) ... = 0`) en is dus onzichtbaar
voor de agent -- het bestand bestaat, maar de MCP-server ziet het niet. Dat maakt het dichten van
dat ene gat geen hygiene maar een echte omissie.

De case-varianten zijn dat wel: de indexer normaliseert (`lower()` + spaties naar dashes), dus die
vallen sowieso samen.

## Waarom het overige geen blokkade is
De indexer normaliseert zelf, dus voor MCP vallen de varianten sowieso samen. Waar het wél
zichtbaar is: de Hugo-taxonomiezijbalk met counts op `linny.toorren.net` toont een variant als een
aparte regel met een eigen telling. Hygiëne en voorspelbaarheid dus, geen afhankelijkheid — deze
story kan parallel aan de rest van de epic.

## Detectiescript
Draaien in de torrlinny-checkout; rapporteert varianten en gaten, en moet aan het eind niets meer
vinden.

```python
import glob, re, collections
norm = lambda t: t.lower().replace(" ", "-")
keys = ("customer", "doctype", "type", "project", "tag", "owner")
raw = collections.defaultdict(collections.Counter); missing = []
for f in sorted(glob.glob("content/**/*.md", recursive=True)):
    m = re.match(r"^---\n(.*?)\n---", open(f, encoding="utf-8", errors="replace").read(), re.S)
    if not m:
        missing.append((f, "geen frontmatter")); continue
    if not re.search(r"^customer\s*:\s*\S", m.group(1), re.M):
        missing.append((f, "geen customer"))
    for k in keys:
        mm = re.search(rf"^{k}\s*:\s*(.*)$", m.group(1), re.M)
        if mm and mm.group(1).strip():
            raw[k][mm.group(1).strip().strip("\"'")] += 1
for k in keys:
    g = collections.defaultdict(list)
    for v, n in raw[k].items():
        g[norm(v)].append((v, n))
    for canon, variants in g.items():
        if len(variants) > 1 or any(v != canon for v, _ in variants):
            print(f"{k}: {canon} <= {variants}")
for f, why in missing:
    print(f"{why}: {f}")
```

## Todo
- [x] detectiescript draaien; lijst met te raken notities vaststellen
- [x] alle case-varianten naar de canonieke (lowercase) vorm brengen
- [x] termen met spaties in `project` naar de dash-vorm, zodat bron en index gelijk zijn
- [ ] de notities zonder `customer` een waarde geven (of bewust een afgesproken placeholder)
- [x] de notitie zonder frontmatter er een geven
- [x] hercontrole: 0 case-varianten; index 117 -> 118 records, geen WARN meer
- [ ] `linny.toorren.net` na de volgende build visueel checken: geen dubbele zijbalk-termen
- [x] committen + pushen naar `torreirow/torrlinny` (ging vanzelf: git-sync op lobos commit en pusht binnen seconden -- commits 4c3b06b + cd85ca2)

## Summary of Changes

Uitgevoerd in `torreirow/torrlinny` (commits `4c3b06b` + `cd85ca2`, al gepusht -- git-sync op lobos
pakte ze binnen seconden op, dus ze staan onder zijn automatische commitbericht en niet onder een
beschrijvende).

- **Case-varianten: 0.** 12 bestanden genormaliseerd naar de indexer-regel (`lower()` + spaties naar
  dashes) over `customer` (6), `project` (7) en `owner` (1).
- **De notitie zonder frontmatter hersteld.** `content/medux-incident-rapport-2026-05-27.md` had er
  geen; `customer: improvement` is afgeleid uit de inhoud (`medux.improvement-it.nl`,
  `IIT-Medux-Production`) en komt overeen met de zusternotitie `medux-rapportage.md`.
  `doctype: client-info` volgt diezelfde notitie.
- **Bewezen effect:** `lindexer build` ging van **117 naar 118 records** en de WARN over malformed
  front matter is weg. Die notitie bestond wél maar stond niet in de index -- hij was dus onzichtbaar
  voor de agent. Dat was geen hygiene maar een echt gat.

## Nog open: 2 notities zonder `customer`

Niet ingevuld omdat een verkeerde klanttoewijzing in je eigen notities erger is dan een leeg veld:

| Notitie | Wat het lijkt | Waarom ik niet gok |
|---------------------|--------------------------------|------------------------------------|
| `content/bedrock.md` | AWS Bedrock-referentie, `tag: [note,woutr]` | kan `torreirow` of `technative` zijn |
| `content/to-do-wk52.md` | weekly-todo, `project: bestuur` | "bestuur" is geen klant uit de lijst |

`content/search.md` is bewust overgeslagen: die heeft `type: "search"` en is een Hugo-zoekpagina,
geen notitie. Daar hoort geen `customer` op.

## Het detectiescript is vervangen (2026-09-28)

Het fragment hierboven staat er nog voor de geschiedenis, maar gebruik het niet meer — het heeft
twee defecten die samen voor veel ruis zorgden:

- een YAML-lijst wordt als één string gelezen, dus `tags: [frontmatter, refactor]` werd gemeld als
  variant `[frontmatter,-refactor]`;
- er is geen uitzonderingslijst, dus zes bestanden die per definitie geen `customer` hebben
  (vijf `_index.md` plus `content/search.md`) werden als gat gemeld.

Op hetzelfde corpus: 9 meldingen waarvan 7 onterecht, tegen 2 echte met de vervanger.

De opvolger staat in torreirow-nixos: `modules/linny-web-frontmatter/check-frontmatter.py`, met
tests en een uitzonderingslijst. OpenSpec-change `add-frontmatter-guard`.

```bash
python3 modules/linny-web-frontmatter/check-frontmatter.py ~/data/git/torreirow/torrlinny
```

## Afgerond 2026-09-28

[x] `content/bedrock.md` en `content/to-do-wk52.md` kregen `customer: technative` (keuze van de
    eigenaar; niet af te leiden uit de inhoud, dus niet geraden).
[x] Eén geval van rand-witruimte hersteld: `customer: torreirow ` in
    `content/alphacourse-2025_2026.md`. Dat was nooit eerder opgemerkt omdat élke lezer die spatie
    stilzwijgend wegstreek — de controle meldt het nu, want anders staat er in de bron iets anders
    dan je typt.
[ ] `linny.toorren.net` visueel checken: geen dubbele zijbalk-termen meer. (Handwerk.)

Commit in torrlinny: `5f83581`. De controle geeft nu exitcode 0 op het hele corpus.

## Zijbalk-controle 2026-09-28: geen duplicaten, maar wél een gat

Counts in de zijbalk tegen het corpus geteld:

    Customers (10)   10 unieke waarden   ✓
    Projects  (17)   17                  ✓
    Types      (8)    8                  ✓
    Tags       (0)    5                  ✗

Geen dubbele termen dus — de normalisatie heeft gewerkt. Maar de tags komen
helemaal niet aan.

**Oorzaak:** drie configuraties zijn het oneens over enkelvoud/meervoud.

    config/_default/config.yaml   tag: "tag"     ← Linny-indexer
    linny-mcp list_taxonomies     "tag"          ← wat de agent ziet
    hugo-web.yaml                 tag: "tags"    ← de website
    linny-web-theme               .Site.Taxonomies.tags (hardgecodeerd)

Bij Hugo is de MEERVOUDSVORM de frontmatter-sleutel. De site keek dus naar een
veld `tags:` dat in geen enkele notitie staat; alle vijf schrijven `tag:`.
De notities volgen de indexer en hebben gelijk.

**Poging tot herstel mislukt en teruggedraaid.** `hugo-web.yaml` op `tag: "tag"`
gezet (commit 148f406) → de build faalde, want de theme codeert `tags` hard:

    menu-filetree.html:95  <len .Site.Taxonomies.tags>
    error calling len: reflect: call of reflect.Value.Type on zero Value

De site bleef op de laatste goede build staan (keep-last-good deed zijn werk),
maar pikte niets nieuws meer op tot de revert (2cb1bc9).

**De echte fix hoort in linny-web-theme.** Regels 95, 98, 128 en 148 van
`layouts/partials/menu-filetree.html`. De andere drie taxonomieën staan er
enkelvoud in; `tags` is de enige die Hugo's standaard volgt in plaats van die
van Linny. Een variant die beide verdraagt zou zijn:

    {{ $tagTax := or (index .Site.Taxonomies "tag") (index .Site.Taxonomies "tags") }}

Let op de reikwijdte: die theme is gedeeld, bedoeld voor álle Linny-notitieboeken.
Een wijziging raakt dus meer dan torrlinny, en vereist een versie-bump plus
`hugo mod get` in elk notitieboek dat meegaat.

[ ] beslissen of en hoe linny-web-theme aangepast wordt
