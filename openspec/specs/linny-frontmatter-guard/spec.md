# linny-frontmatter-guard Specification

## Purpose
TBD - created by archiving change add-frontmatter-guard. Update Purpose after archive.

## Requirements

### Requirement: De controle hanteert dezelfde termvorm als de indexer

De controle SHALL een term als canoniek beschouwen wanneer die volledig in kleine letters staat en
geen spaties bevat, gelijk aan de normalisatie die de Linny-indexer toepast.

#### Scenario: Afwijkend hoofdlettergebruik wordt gemeld

- **WHEN** een notitie een taxonomie-term bevat met een hoofdletter
- **THEN** de controle SHALL die term melden met de canonieke vorm erbij
- **AND** SHALL afsluiten met een exitcode die faalt

#### Scenario: Spatie in een term wordt gemeld

- **WHEN** een notitie een taxonomie-term bevat met een spatie
- **THEN** de controle SHALL die term melden, omdat de indexer er stilzwijgend een streepje van
  maakt en bron en index dan uiteenlopen

#### Scenario: Een schoon corpus faalt niet

- **WHEN** alle termen canoniek zijn en er geen gaten zijn
- **THEN** de controle SHALL afsluiten met een exitcode die slaagt
- **AND** SHALL niets als afwijking melden

### Requirement: Lijstwaarden worden per element getoetst

De controle SHALL elk element van een lijstwaarde afzonderlijk toetsen en SHALL NOT de lijst als
één term behandelen.

#### Scenario: Een geldige lijst levert geen melding op

- **WHEN** een notitie `tags: [frontmatter, refactor]` bevat
- **THEN** de controle SHALL beide elementen als canoniek beschouwen
- **AND** SHALL NOT de lijst als geheel als afwijkende term melden

#### Scenario: Eén afwijkend element in een lijst wordt gemeld

- **WHEN** een notitie een lijst bevat waarvan één element een hoofdletter of spatie heeft
- **THEN** de controle SHALL uitsluitend dat element melden

### Requirement: Witruimte rond een scalar-waarde wordt gemeld

De controle SHALL melden wanneer een scalar-waarde begint of eindigt met witruimte, ook wanneer de
waarde verder canoniek is.

Een YAML-lezer strijkt zulke witruimte weg, dus de betekenis verandert niet. Juist daardoor valt het
niemand op, terwijl er in de bron iets anders staat dan wat er geïndexeerd wordt.

#### Scenario: Spatie achter een scalar

- **WHEN** een notitie `customer: technative ` bevat, met een spatie aan het eind
- **THEN** de controle SHALL dat melden als witruimte-afwijking
- **AND** SHALL NOT dezelfde waarde óók als niet-canonieke term melden

#### Scenario: Witruimte in een inline lijst telt niet

- **WHEN** een notitie `tags: [frontmatter,  refactor ]` bevat
- **THEN** de controle SHALL NOT melden, omdat witruimte rond een element in een inline lijst
  structureel is en geen onderdeel van de waarde

#### Scenario: Witruimte in een block-lijst telt wel

- **WHEN** een element van een block-lijst eindigt met witruimte
- **THEN** de controle SHALL dat melden

### Requirement: Ontbrekende frontmatter is een fout, geen waarschuwing

Een notitie zonder frontmatter SHALL als fout gemeld worden, met vermelding dat zo'n notitie niet in
de index belandt en daardoor onvindbaar is.

#### Scenario: Notitie zonder frontmatter

- **WHEN** een bestand in het corpus geen frontmatter-blok heeft
- **THEN** de controle SHALL het bestand melden
- **AND** SHALL afsluiten met een exitcode die faalt

### Requirement: Bestanden zonder eigen taxonomie zijn uitgezonderd

De controle SHALL een expliciete lijst hanteren van bestanden waarvoor een verplicht veld niet
geldt, zodat een schone run ook werkelijk leeg is.

#### Scenario: Sectie-indexpagina's tellen niet mee

- **WHEN** het corpus `_index.md`-bestanden bevat zonder `customer`
- **THEN** de controle SHALL die niet als ontbrekend veld melden

#### Scenario: Een uitgezonderd bestand met een afwijkende term telt wél mee

- **WHEN** een uitgezonderd bestand een taxonomie-term bevat die niet canoniek is
- **THEN** de controle SHALL die term alsnog melden; de uitzondering geldt uitsluitend voor het
  verplichte veld, niet voor de termvorm

### Requirement: De controle wijzigt niets en blokkeert de publicatie niet

De controle SHALL uitsluitend lezen, en SHALL NOT onderdeel zijn van de voorwaarden waaronder het
notitieboek gebouwd en gepubliceerd wordt.

#### Scenario: Het corpus blijft ongewijzigd

- **WHEN** de controle over een corpus draait
- **THEN** SHALL geen bestand in dat corpus zijn gewijzigd, toegevoegd of verwijderd

#### Scenario: Een afwijking houdt de site niet tegen

- **WHEN** de controle afwijkingen vindt
- **THEN** de bestaande bouw- en publicatiestroom van het notitieboek SHALL ongewijzigd doorlopen
