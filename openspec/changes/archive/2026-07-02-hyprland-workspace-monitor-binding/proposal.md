## Why

Workspaces in Hyprland zweven vrij tussen monitors, waardoor apps als Slack, Teams en Firefox steeds op wisselende schermen belanden na een herstart of herverbinding. Door workspaces vast te koppelen aan monitoren en apps automatisch naar hun workspace te sturen ontstaat een consistente werkplek — ook als het externe scherm niet is aangesloten.

## What Changes

- Workspaces 1-10 worden persistent gemaakt (bestaan altijd, ook als leeg)
- Workspace 1 wordt standaard gekoppeld aan DP-10 (extern scherm)
- Workspace 2 wordt standaard gekoppeld aan eDP-1 (laptopscherm)
- Workspace 3 wordt gekoppeld aan eDP-1 voor Slack en Teams
- Workspace 4 wordt gekoppeld aan DP-10 voor Firefox
- Windowrules zorgen dat Slack, teams-for-linux en Firefox automatisch naar hun workspace gaan bij openen
- Bij ontbreken extern scherm vallen DP-10-workspaces terug op eDP-1 (Hyprland standaardgedrag)

## Capabilities

### New Capabilities

- `workspace-monitor-binding`: Vaste koppeling van workspaces aan monitoren via Hyprland workspace-regels, met persistent:true voor alle workspaces 1-10
- `app-workspace-assignment`: Automatische plaatsing van apps op vaste workspaces via windowrules (Slack, Teams → WS3; Firefox → WS4)

### Modified Capabilities

## Impact

- `home/hyprland/default.nix`: workspace-bindings toevoegen aan settings
- `home/hyprland/windows.nix`: windowrules toevoegen voor Slack, teams-for-linux, Firefox
- Geen wijzigingen aan wayle, waybar, of andere componenten
- Gedrag bij één monitor: alle workspaces op eDP-1, apps bereikbaar via SUPER+1 t/m SUPER+4
