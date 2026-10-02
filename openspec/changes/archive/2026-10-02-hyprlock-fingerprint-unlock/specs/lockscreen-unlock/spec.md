# Spec Delta

## Purpose

Legt vast hoe het lockscreen van lobos ontgrendeld kan worden: met een wachtwoord of een
geregistreerde vingerafdruk, naast elkaar, zonder dat de ene methode de andere blokkeert.

## ADDED Requirements

### Requirement: Ontgrendelen met vingerafdruk
Het lockscreen SHALL ontgrendelen wanneer de gebruiker een geregistreerde vinger op de sensor legt,
zonder dat eerst iets getypt of aangeklikt hoeft te worden.

#### Scenario: Geregistreerde vinger direct na vergrendelen
- **WHEN** het scherm vergrendeld is en de gebruiker een geregistreerde vinger op de sensor legt
- **THEN** ontgrendelt het lockscreen

#### Scenario: Niet-geregistreerde vinger
- **WHEN** het scherm vergrendeld is en er een niet-geregistreerde vinger op de sensor ligt
- **THEN** blijft het scherm vergrendeld en blijft ontgrendelen met wachtwoord of een geregistreerde
  vinger mogelijk

### Requirement: Wachtwoord blijft direct bruikbaar
Ontgrendelen met wachtwoord SHALL altijd beschikbaar zijn en SHALL NOT wachten op de
vingerafdruksensor (geen timeout of vertraging door de vingerafdruk).

#### Scenario: Wachtwoord typen zonder vinger
- **WHEN** het scherm vergrendeld is en de gebruiker meteen het juiste wachtwoord typt en op Enter drukt
- **THEN** ontgrendelt het lockscreen binnen dezelfde tijd als vóór deze wijziging

#### Scenario: Sensor niet bereikbaar
- **WHEN** de sensor niet te gebruiken is (klep dicht, fprintd niet beschikbaar)
- **THEN** ontgrendelt het juiste wachtwoord het lockscreen gewoon

### Requirement: Vingerafdruk-icoon zonder statustekst
Het lockscreen SHALL onder het invoerveld een statisch vingerafdruk-icoon tonen als hint dat ontgrendelen
met de vinger kan. Het SHALL geen statustekst of prompt voor de vingerafdruk tonen.

#### Scenario: Vergrendeld scherm
- **WHEN** het scherm vergrendeld is
- **THEN** toont het lockscreen achtergrond, klok, invoerveld en daaronder een vingerafdruk-icoon, en
  geen fingerprint-statustekst

### Requirement: Lock-teksten rouleren per vergrendeling
De placeholdertekst en de fouttekst van het lockscreen SHALL bij elke nieuwe vergrendeling willekeurig
uit een vaste lijst gekozen worden. Een fout in het kiezen SHALL het vergrendelen niet verhinderen.

#### Scenario: Twee vergrendelingen achter elkaar
- **WHEN** de gebruiker vergrendelt, ontgrendelt en opnieuw vergrendelt
- **THEN** kan de placeholdertekst verschillen van die van de vorige vergrendeling, en komt hij uit de lijst

#### Scenario: Fout wachtwoord
- **WHEN** de gebruiker een fout wachtwoord invoert
- **THEN** toont het invoerveld een fouttekst uit de lijst

#### Scenario: Tekstbestand ontbreekt
- **WHEN** het bestand met de gekozen teksten ontbreekt
- **THEN** vergrendelt het scherm gewoon, en ontgrendelen met wachtwoord of vinger werkt

### Requirement: Vingerafdruk werkt na suspend/resume
Wanneer het scherm vóór een suspend vergrendeld werd, SHALL ontgrendelen met vingerafdruk na de
resume werken, zonder handmatig ingrijpen.

#### Scenario: Vergrendelen + suspend, daarna vinger
- **WHEN** de gebruiker vergrendelt en suspendt (SUPER+SHIFT+L of klep/idle-suspend), het systeem
  hervat, en de gebruiker een geregistreerde vinger op de sensor legt
- **THEN** ontgrendelt het lockscreen
