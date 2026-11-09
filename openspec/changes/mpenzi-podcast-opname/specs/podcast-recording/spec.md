# Spec Delta

## Purpose

Een podcast opnemen op mpenzi met twee USB-microfoons, elke stem op een eigen spoor, via Audacity
of via een opnameknop, zonder virtuele mixer zoals Voicemeeter.

## ADDED Requirements

### Requirement: Vaste naam per USB-poort
mpenzi SHALL een USB-microfoon in de poort `pci-0000:04:00.3-usb-0:2:1.0` (rechts, bij het scherm)
tonen als "Podcast mic 1" en in `pci-0000:04:00.4-usb-0:2:1.0` (rechts, bij de gebruiker) als
"Podcast mic 2". De naam MUST van de poort afhangen, niet van serienummer of volgorde van
aansluiten.

#### Scenario: Twee identieke microfoons
- **WHEN** twee NZXT Capsules met hetzelfde serienummer in beide poorten zitten
- **THEN** zijn er twee bronnen "Podcast mic 1" en "Podcast mic 2"

#### Scenario: Microfoons verwisseld
- **WHEN** de twee microfoons van poort wisselen
- **THEN** heet de microfoon in de poort bij het scherm nog steeds "Podcast mic 1"

#### Scenario: Andere poort
- **WHEN** een Capsule in een andere poort of via een hub zit
- **THEN** krijgt hij geen podcastnaam en verschijnt hij als gewone microfoon

### Requirement: Capsules niet vanzelf standaard
Een aangesloten Capsule MUST NOT vanzelf de standaardmicrofoon of de standaard-uitvoer van mpenzi
worden; de laptopmicrofoon en -speakers blijven standaard tenzij de gebruiker zelf kiest.

#### Scenario: Microfoons aangesloten
- **WHEN** beide Capsules aangesloten worden
- **THEN** speelt het laptopgeluid nog via de speakers en gebruikt Zoom nog de laptopmicrofoon

### Requirement: Virtuele stereobron voor Audacity
mpenzi SHALL een opnamebron "Podcast (2 mics)" bieden met twee kanalen: links het geluid van
"Podcast mic 1", rechts dat van "Podcast mic 2". Het volume per microfoon MUST met de gewone
Plasma-schuif van die microfoon te regelen zijn.

#### Scenario: Opnemen in stereo
- **WHEN** Maaike in Audacity met 2 kanalen van "Podcast (2 mics)" opneemt en alleen in mic 1 praat
- **THEN** staat haar stem alleen op het linkerkanaal

#### Scenario: Volume bijsturen
- **WHEN** de schuif van "Podcast mic 2" omlaag gaat
- **THEN** wordt alleen het rechterkanaal zachter

### Requirement: Opnameknop met twee bestanden
mpenzi SHALL `podrec start` en `podrec stop` bieden, ook als menu-items. Een opname MUST beide
microfoons gelijktijdig vastleggen als `mic1.flac` en `mic2.flac` (mono) in een nieuwe map
`~/Podcast/<datum>_<tijd>/`, en de gebruiker een melding geven bij start en stop.

#### Scenario: Opname maken
- **WHEN** Maaike "Podcast opname starten" kiest, praat en daarna "Podcast opname stoppen" kiest
- **THEN** staan in een nieuwe map onder `~/Podcast/` twee afspeelbare FLAC-bestanden van ongeveer
  dezelfde duur

#### Scenario: Al bezig
- **WHEN** `podrec start` gekozen wordt terwijl er al een opname loopt
- **THEN** start er geen tweede opname en meldt het dat er al opgenomen wordt

### Requirement: Melding bij ontbrekende microfoon
`podrec start` MUST weigeren te starten en melden welke microfoon ontbreekt als "Podcast mic 1"
of "Podcast mic 2" niet aanwezig is, en melden dat een herstart nodig is als "Podcast (2 mics)"
ontbreekt.

#### Scenario: Mic 2 niet aangesloten
- **WHEN** alleen de poort bij het scherm een microfoon heeft en Maaike een opname start
- **THEN** start er geen opname en meldt het dat "Podcast mic 2" ontbreekt

#### Scenario: Stereobron nog niet geladen
- **WHEN** beide microfoons er zijn maar "Podcast (2 mics)" ontbreekt
- **THEN** start er geen opname en zegt de melding dat een herstart nodig is
