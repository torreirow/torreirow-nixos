# meeting-record Specification

## Purpose
Opname van beide kanten van een online gesprek (Teams, Slack, Jitsi) op lobos: de inkomende
audio en de eigen microfoon, als twee gescheiden sporen, met nabewerking en transcriptie.

## Requirements

### Requirement: Twee gescheiden sporen per opname
Het systeem SHALL per opname twee losse audiobestanden aanmaken: één met de inkomende audio en
één met de eigen microfoon. Het systeem SHALL de sporen NIET live samenvoegen.

#### Scenario: Opname gestart
- **WHEN** `meetrec start` wordt uitgevoerd
- **THEN** ontstaan er twee opnameprocessen die schrijven naar `anderen.wav` en `ik.wav` in
  dezelfde opnamemap

#### Scenario: Opname gestopt
- **WHEN** `meetrec stop` wordt uitgevoerd na een opname
- **THEN** bevat de opnamemap twee afzonderlijke, afspeelbare geluidsbestanden

### Requirement: Bronnen volgen de standaard-apparaten
Het systeem SHALL de inkomende audio opnemen van de monitor van de op dat moment actieve
standaard-uitvoer, en de eigen microfoon van de op dat moment actieve standaard-invoer. Het
systeem SHALL geen apparaatnamen of node-id's vastleggen bij het starten.

#### Scenario: Inkomend spoor koppelt aan de standaard-uitvoer
- **WHEN** een opname loopt
- **THEN** is het opnameproces van het inkomende spoor gekoppeld aan de monitorpoorten van de
  huidige standaard-uitvoer

#### Scenario: Apparaat wisselt tijdens de opname
- **WHEN** tijdens een lopende opname de standaard-uitvoer wijzigt (bijvoorbeeld een
  Bluetooth-headset die verbindt)
- **THEN** blijft het inkomende spoor doorlopen en volgt het de nieuwe standaard-uitvoer

### Requirement: Opname begint alleen op expliciete opdracht
Het systeem SHALL nooit uit zichzelf een opname starten. Een opname SHALL uitsluitend beginnen
door een expliciete aanroep van `meetrec start`.

#### Scenario: Geen achtergronddienst
- **WHEN** de module is ingeschakeld maar er is geen `meetrec start` gegeven
- **THEN** draait er geen opnameproces en is er geen timer of dienst die er een kan starten

### Requirement: Opnamestaat is opvraagbaar
Het systeem SHALL een lopende opname herkenbaar maken met `meetrec status`, inclusief de
opnamemap, de starttijd en de bronnen waaraan de sporen hangen. Het systeem SHALL bij het
ontbreken van een lopende opname dat expliciet melden.

#### Scenario: Opname loopt
- **WHEN** `meetrec status` wordt uitgevoerd terwijl een opname loopt
- **THEN** toont de uitvoer de opnamemap, de verstreken tijd en de omvang van beide sporen

#### Scenario: Geen opname
- **WHEN** `meetrec status` wordt uitgevoerd zonder lopende opname
- **THEN** meldt het commando dat er niets loopt en eindigt het zonder fout

#### Scenario: Opnameproces is omgevallen
- **WHEN** een van beide opnameprocessen niet meer draait terwijl de staat nog een lopende
  opname aangeeft
- **THEN** meldt `meetrec status` dat expliciet in plaats van een gezonde opname te suggereren

### Requirement: Rauwe opname tijdens het gesprek, compressie erna
Het systeem SHALL tijdens de opname naar een ongecomprimeerd formaat schrijven en SHALL pas bij
`meetrec stop` comprimeren. Het systeem SHALL het ongecomprimeerde bestand pas verwijderen nadat
de compressie is geslaagd.

#### Scenario: Succesvolle compressie
- **WHEN** `meetrec stop` de sporen comprimeert en dat slaagt
- **THEN** staan er gecomprimeerde bestanden in de opnamemap en zijn de ongecomprimeerde
  bestanden verwijderd

#### Scenario: Mislukte compressie
- **WHEN** de compressie van een spoor mislukt
- **THEN** blijft het ongecomprimeerde bestand staan en meldt het commando de fout

### Requirement: Opnamemap per gesprek
Het systeem SHALL elke opname in een eigen map plaatsen, benoemd naar het startmoment, onder een
instelbare basismap.

#### Scenario: Twee opnames na elkaar
- **WHEN** twee opnames op verschillende momenten worden gestart
- **THEN** krijgt elke opname een eigen map en overschrijft de tweede de eerste niet

### Requirement: Optionele samenvoeging tot één bestand
Het systeem SHALL op verzoek de twee sporen samenvoegen tot één bestand. Het systeem SHALL de
losse sporen daarbij bewaren.

#### Scenario: Samenvoegen
- **WHEN** `meetrec mix` op een afgeronde opname wordt uitgevoerd
- **THEN** ontstaat er een extra gemengd bestand en blijven beide sporen bestaan

### Requirement: Transcriptie per spoor met sprekerlabels
Het systeem SHALL op verzoek elk spoor afzonderlijk transcriberen en de resultaten samenvoegen
tot één tijdgeordend transcript waarin per regel zichtbaar is van welk spoor die komt.

#### Scenario: Transcriptie van een afgeronde opname
- **WHEN** `meetrec transcribe` op een afgeronde opname wordt uitgevoerd
- **THEN** ontstaat er een transcript waarin de regels op tijd geordend zijn en per regel een
  sprekerlabel dragen

#### Scenario: Transcriptie belast het gesprek niet
- **WHEN** transcriptie wordt uitgevoerd
- **THEN** gebeurt dat als losse stap na de opname, met verlaagde CPU- en I/O-prioriteit
