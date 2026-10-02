# Design

## Context

- `home/hyprland/default.nix`: `monitor = [ "eDP-1,preferred,auto,1.25" "HDMI-A-1,preferred,auto,1" ]`.
  Andere externe outputs (`DP-*`, DisplayLink `DVI-I-1`) vallen terug op Hyprland's default
  (preferred, auto, rechts naast de laptop).
- `home/hyprland/wayle.nix` heeft twee socket2-listeners: `hyprland-workspace-binder` (ws 1,4,6,8,10 →
  eerste niet-eDP-1, ws 3,5,7,9 → eDP-1, bij `monitoraddedv2`/`monitorremoved`) en
  `wayle-monitor-router` (notificaties + OSD naar het externe scherm).
- SUPER+P = `pseudo`. SUPER+SHIFT+P is vrij. `bindings.nix` heeft ook een hulptekst met alle bindings.
- DisplayLink (evdi) is nog actief in de NixOS-config. Dit change raakt dat niet.

## Goals / Non-Goals

**Goals:**
- Vier standen via één menu (zie spec), robuust tegen een zwart laptopscherm na loskoppelen.

**Non-Goals:**
- Automatische profielen per scherm/locatie (kanshi/shikane), lid-switch, onthouden van de stand.
- Een revert-timer bij "Alleen extern". De user vindt het vangnet (kabel eruit → laptop aan) genoeg.
- Schaal- of resolutiekeuze per stand.

## Decisions

### 1. Runtime `hyprctl keyword monitor`, niet de config herschrijven
De standen zijn monitor-regels die runtime gezet worden:

| Stand         | Regels                                                              |
|---------------|---------------------------------------------------------------------|
| Uitgebreid    | `eDP-1,preferred,auto,1.25` + `EXT,preferred,auto,1`                |
| Klonen        | `eDP-1,preferred,auto,1.25` + `EXT,preferred,auto,1,mirror,eDP-1`   |
| Alleen extern | `EXT,preferred,auto,1` + `eDP-1,disable`                            |
| Alleen laptop | `eDP-1,preferred,auto,1.25` + `EXT,disable`                         |

Volgorde: zet eerst het scherm áán dat blijft, pas daarna het andere uit. Zo is er nooit een moment
zonder actieve output. Runtime-regels verdwijnen bij een reload, en dat is precies "niet onthouden"
(spec). De eDP-1-regel in het script moet gelijk blijven aan `default.nix` (scale 1.25). Het script
haalt die regel daarom niet uit de config maar krijgt hem als Nix-variabele mee, met dezelfde waarde
als `default.nix` (één bron in een `let`).
- *Alternatief: config-bestand herschrijven + `hyprctl reload`.* Afgewezen: een reload zet ook andere
  runtime-state terug en is trager.

### 2. "Extern" = eerste niet-eDP-1 uit `hyprctl monitors all -j`
`monitors all` toont ook uitgeschakelde outputs, zodat "Uitgebreid" na "Alleen laptop" de naam nog
kent. Een gemirrorde output verschijnt ook alleen in `monitors all`. De detectie is dezelfde als in de
binder (alleen `all` erbij), zodat HDMI, DP en DisplayLink gelijk behandeld worden.

### 3. Menu = fuzzel `--dmenu`, script als `writeShellApplication`
Gelijk aan de bestaande cliphist-picker. Labels met Nerd-Font-iconen. Escape/leeg = niets doen.
Geen extern scherm → `notify-send` en exit 0, zonder het menu te openen.

### 4. Vangnet in de bestaande binder-listener, niet een derde listener
`hyprland-workspace-binder` luistert al naar `monitorremoved`. Daar komt bij: is `eDP-1` uitgeschakeld
en is er geen andere actieve output meer, dan `hyprctl keyword monitor eDP-1,preferred,auto,1.25`.
`bind_workspaces` moet daarnaast "eDP-1 niet actief" aankunnen: dan niet `wsbind` naar eDP-1, want
Hyprland zet de workspaces dan al zelf op het enige scherm.
- *Alternatief: een eigen service.* Afgewezen: nog een socket2-listener voor één `case`-regel.

### 5. Workspaces na een standwissel
Uitzetten/aanzetten van een output geeft naar verwachting `monitorremoved`/`monitoraddedv2`, waarop de
binder al reageert. Taak 1 (spike) controleert dat. Komen de events niet, dan roept het script na het
toepassen zelf de binding opnieuw aan (de binder wordt dan een losse functie die beide aanroepen).

## Risks / Trade-offs

- [Alleen extern op een scherm dat niets toont → beide zwart] → Geaccepteerd. Kabel eruit = laptop
  terug (decision 4).
- [Klonen bij 1920x1200@1.25 vs 1080p → zwarte balken of schaling] → Geaccepteerd. Hyprland mirrort de
  bron. De spike laat zien hoe het eruitziet.
- [Klonen over DisplayLink (evdi) is fragiel] → Buiten de test van dit change. DisplayLink wordt nu
  niet gebruikt.
- [Wayle-router bij Klonen ziet geen apart extern scherm] → Notificaties blijven op eDP-1, en die is
  gekloond, dus ze zijn op beide te zien.

## Migration Plan

`home-manager switch`. Rollback = binding + script weghalen, of vorige HM-generatie.
