## ADDED Requirements

### Requirement: Workspaces zijn persistent en altijd aanwezig
Alle workspaces 1 t/m 10 MOETEN altijd bestaan, ook als ze geen vensters bevatten. Ze MOGEN niet verdwijnen na sluiten van het laatste venster.

#### Scenario: Lege workspace blijft zichtbaar
- **WHEN** alle vensters op workspace 5 worden gesloten
- **THEN** workspace 5 blijft bestaan en is bereikbaar via SUPER+5

### Requirement: Workspace 1 is standaard gekoppeld aan het externe scherm
Workspace 1 SHALL als default workspace op het externe scherm staan wanneer een extern scherm is aangesloten. De koppeling is dynamisch: de `hyprland-workspace-binder` service detecteert automatisch de eerste niet-eDP-1 monitor, ongeacht poortnaam (HDMI-A-1, DP-10, enz.).

#### Scenario: Opstarten met extern scherm
- **WHEN** Hyprland opstart met zowel eDP-1 als een extern scherm aangesloten
- **THEN** toont het externe scherm workspace 1 als actieve workspace

#### Scenario: Extern scherm ontbreekt
- **WHEN** Hyprland opstart zonder extern scherm
- **THEN** is workspace 1 beschikbaar op eDP-1 en bereikbaar via SUPER+1

### Requirement: Workspace 2 is standaard gekoppeld aan het laptopscherm
Workspace 2 SHALL als default workspace op monitor eDP-1 (laptopscherm) staan.

#### Scenario: Opstarten met twee schermen
- **WHEN** Hyprland opstart met beide monitoren
- **THEN** toont eDP-1 workspace 2 als actieve workspace

### Requirement: Workspace 3 is gekoppeld aan het laptopscherm
Workspace 3 SHALL aan monitor eDP-1 gebonden zijn.

#### Scenario: Navigeren naar workspace 3
- **WHEN** gebruiker drukt SUPER+3
- **THEN** springt de focus naar eDP-1 en toont workspace 3

### Requirement: Workspace 4 is gekoppeld aan het externe scherm
Workspace 4 SHALL dynamisch aan het externe scherm gebonden zijn wanneer dat is aangesloten.

#### Scenario: Navigeren naar workspace 4 met extern scherm
- **WHEN** gebruiker drukt SUPER+4 en een extern scherm is aangesloten
- **THEN** springt de focus naar het externe scherm en toont workspace 4

#### Scenario: Navigeren naar workspace 4 zonder extern scherm
- **WHEN** gebruiker drukt SUPER+4 en alleen eDP-1 is beschikbaar
- **THEN** is workspace 4 zichtbaar op eDP-1
