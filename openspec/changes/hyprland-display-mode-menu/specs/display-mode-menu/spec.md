# Spec Delta

## Purpose

Laat de gebruiker op lobos met één toets kiezen hoe een extern scherm gebruikt wordt (uitgebreid,
klonen, alleen extern, alleen laptop), zonder dat een stand het laptopscherm onbruikbaar achterlaat.

## ADDED Requirements

### Requirement: Schermstand-menu via SUPER+SHIFT+P
SUPER+SHIFT+P SHALL een menu openen met de vier standen Uitgebreid, Klonen, Alleen extern en Alleen
laptop. Een gekozen stand SHALL direct worden toegepast. Sluiten van het menu zonder keuze SHALL niets
veranderen.

#### Scenario: Menu openen en annuleren
- **WHEN** een extern scherm is aangesloten, de gebruiker SUPER+SHIFT+P drukt en het menu sluit met Escape
- **THEN** blijft de schermopstelling ongewijzigd

### Requirement: Uitgebreid
De stand Uitgebreid SHALL zowel het laptopscherm als het externe scherm aanzetten als afzonderlijke
schermen naast elkaar, zoals de standaardopstelling.

#### Scenario: Terug naar uitgebreid na alleen laptop
- **WHEN** de stand Alleen laptop actief is en de gebruiker Uitgebreid kiest
- **THEN** staan beide schermen aan als afzonderlijke schermen

### Requirement: Klonen
De stand Klonen SHALL het externe scherm de inhoud van het laptopscherm laten tonen.

#### Scenario: Presenteren
- **WHEN** de gebruiker Klonen kiest
- **THEN** toont het externe scherm hetzelfde beeld als het laptopscherm

### Requirement: Alleen extern
De stand Alleen extern SHALL het laptopscherm uitzetten en alleen het externe scherm gebruiken. Alle
workspaces SHALL dan op het externe scherm bereikbaar zijn.

#### Scenario: Laptopscherm uit
- **WHEN** de gebruiker Alleen extern kiest
- **THEN** is het laptopscherm uit en staan alle workspaces op het externe scherm

### Requirement: Alleen laptop
De stand Alleen laptop SHALL het externe scherm uitzetten en alleen het laptopscherm gebruiken.

#### Scenario: Extern scherm uit
- **WHEN** de gebruiker Alleen laptop kiest
- **THEN** is het externe scherm uit en staan alle workspaces op het laptopscherm

### Requirement: Werkt met elk extern scherm
Als extern scherm SHALL de eerste output gelden die niet het laptopscherm is, ongeacht de aansluiting
(HDMI, USB-C/DisplayPort, DisplayLink), ook wanneer die output op dat moment uitgeschakeld staat.

#### Scenario: USB-C-scherm
- **WHEN** het externe scherm via USB-C (DP-output) is aangesloten en de gebruiker een stand kiest
- **THEN** wordt die stand op dat scherm toegepast

### Requirement: Geen extern scherm
Zonder aangesloten extern scherm SHALL het menu een korte melding geven en niets veranderen.

#### Scenario: Alleen de laptop
- **WHEN** er geen extern scherm is aangesloten en de gebruiker SUPER+SHIFT+P drukt
- **THEN** verschijnt een melding dat er geen extern scherm is en blijft het laptopscherm zoals het was

### Requirement: Laptopscherm komt terug bij loskoppelen
Wanneer het externe scherm verdwijnt terwijl het laptopscherm uit staat, SHALL het laptopscherm
automatisch weer aangaan.

#### Scenario: Kabel eruit in Alleen extern
- **WHEN** de stand Alleen extern actief is en het externe scherm wordt losgekoppeld
- **THEN** gaat het laptopscherm vanzelf weer aan en zijn alle workspaces daar bereikbaar

### Requirement: Stand wordt niet onthouden
Een gekozen stand SHALL NOT bewaard worden. Na een Hyprland-herstart of -reload SHALL de standaard-
opstelling (Uitgebreid) gelden.

#### Scenario: Na herstart
- **WHEN** de stand Klonen actief was en Hyprland opnieuw start
- **THEN** staan de schermen weer als Uitgebreid
