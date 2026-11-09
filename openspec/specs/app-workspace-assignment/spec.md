# app-workspace-assignment Specification

## Purpose
Vaste workspaces voor communicatie- en werk-apps in Hyprland op lobos: de apps openen stil (zonder focuswissel) op hun eigen workspace, zodat ze het lopende werk niet onderbreken.

## Requirements

### Requirement: Slack opent altijd op workspace 2
Slack SHALL bij het openen automatisch op workspace 2 geplaatst worden zonder de actieve focus te verstoren.

#### Scenario: Slack starten vanuit launcher
- **WHEN** gebruiker Slack opent via app launcher of keybinding
- **THEN** verschijnt Slack op workspace 2
- **THEN** wisselt het actieve scherm NIET van focus

#### Scenario: Slack herstart na crash
- **WHEN** Slack opnieuw opstart
- **THEN** verschijnt Slack op workspace 2, niet op de huidige workspace

### Requirement: Microsoft Teams opent altijd op workspace 3
teams-for-linux SHALL bij het openen automatisch op workspace 3 geplaatst worden zonder de actieve focus te verstoren.

#### Scenario: Teams starten
- **WHEN** gebruiker Teams opent
- **THEN** verschijnt Teams op workspace 3

### Requirement: Firefox opent altijd op workspace 4
Firefox SHALL bij het openen automatisch op workspace 4 geplaatst worden zonder de actieve focus te verstoren.

#### Scenario: Firefox starten via keybinding
- **WHEN** gebruiker SUPER+B drukt
- **THEN** opent Firefox op workspace 4
- **THEN** wisselt de actieve workspace NIET automatisch

#### Scenario: Firefox starten terwijl extern scherm is aangesloten
- **WHEN** gebruiker Firefox opent en DP-10 is aangesloten
- **THEN** verschijnt Firefox op workspace 4 op DP-10

#### Scenario: Firefox starten zonder extern scherm
- **WHEN** gebruiker Firefox opent en alleen eDP-1 is beschikbaar
- **THEN** verschijnt Firefox op workspace 4 op eDP-1
