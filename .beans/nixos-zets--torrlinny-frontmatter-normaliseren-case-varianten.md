---
# nixos-zets
title: torrlinny-frontmatter normaliseren (case-varianten + ontbrekende customer)
status: todo
type: task
priority: normal
created_at: 2026-09-25T07:43:48Z
updated_at: 2026-09-25T08:06:10Z
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

## Waarom dit geen blokkade is
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
- [ ] detectiescript draaien; lijst met te raken notities vaststellen
- [ ] alle case-varianten naar de canonieke (lowercase) vorm brengen
- [ ] termen met spaties in `project` naar de dash-vorm, zodat bron en index gelijk zijn
- [ ] de notities zonder `customer` een waarde geven (of bewust een afgesproken placeholder)
- [ ] de notitie zonder frontmatter er een geven
- [ ] hercontrole: het script rapporteert niets meer
- [ ] `linny.toorren.net` na de volgende build visueel checken: geen dubbele zijbalk-termen
- [ ] committen + pushen naar `torreirow/torrlinny`
