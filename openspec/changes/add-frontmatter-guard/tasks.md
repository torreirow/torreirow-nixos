## 1. Het script

- [ ] 1.1 `modules/linny-web-frontmatter/check-frontmatter.py`: corpuspad als argument (standaard
      de huidige map), exitcode 1 bij afwijkingen
- [ ] 1.2 Normalisatie als één functie bovenaan, met de verwijzing naar linny-mcp erbij —
      wijkt upstream af, dan is dit de plek die mee moet
- [ ] 1.3 Frontmatter-blok met de hand ontleden; onderscheid maken tussen "geen frontmatter" en
      "frontmatter aanwezig maar veld ontbreekt"
- [ ] 1.4 Lijstwaarden herkennen in **beide** YAML-vormen (inline `[a, b]` en block met `- `) en
      elk element afzonderlijk toetsen
- [ ] 1.5 Uitzonderingslijst als patronen (`**/_index.md`, `content/search.md`), uitsluitend voor
      het verplichte veld — de termvorm geldt er wél
- [ ] 1.6 Uitvoer die de canonieke vorm naast de gevonden vorm zet, zodat de correctie voor de hand
      ligt; bij ontbrekende frontmatter erbij vermelden dat zo'n notitie niet in de index komt

## 2. Tests

- [ ] 2.1 `check_frontmatter_test.py`: draait zonder corpus en zonder netwerk, bouwt zijn eigen
      bestanden in een tijdelijke map
- [ ] 2.2 Hoofdletter en spatie in een scalar worden gemeld
- [ ] 2.3 `tags: [frontmatter, refactor]` levert **geen** melding op — dit is het defect in het
      script uit de bean en de reden dat deze change bestaat
- [ ] 2.4 Block-lijst met één afwijkend element: alleen dat element wordt gemeld
- [ ] 2.5 Bestand zonder frontmatter wordt gemeld
- [ ] 2.6 `_index.md` zonder `customer` wordt **niet** gemeld
- [ ] 2.7 Uitgezonderd bestand mét een afwijkende term wordt **wel** gemeld
- [ ] 2.8 Schoon corpus: exitcode 0 en lege uitvoer
- [ ] 2.9 Het script wijzigt niets: mtimes en inhoud van het corpus voor en na gelijk

## 3. Toetsen op het echte corpus

- [ ] 3.1 Draaien op de werkkopie op lobos (`~/data/git/torreirow/torrlinny`)
- [ ] 3.2 Verwachte uitkomst vastleggen: 0 termafwijkingen en precies twee ontbrekende
      `customer`-velden (`content/bedrock.md`, `content/to-do-wk52.md`) — géén `_index.md`'s,
      géén valse lijstmelding
- [ ] 3.3 Bevestigen dat de uitvoer van het oude beanscript hierop afweek, zodat vastligt wat er
      gerepareerd is

## 4. Documentatie

- [ ] 4.1 `docs/torrlinny.md`: korte sectie over de canonieke termvorm en hoe je de controle draait
- [ ] 4.2 `CHANGELOG.md` onder `## NEXT VERSION`
- [ ] 4.3 Bean `nixos-zets` bijwerken: het script vervangt het fragment in de bean; de twee
      ontbrekende `customer`-waarden blijven daar openstaan als inhoudelijke keuze
