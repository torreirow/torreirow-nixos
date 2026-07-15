## Context

De huidige setup heeft:
- `clipse -listen` als clipboard history daemon (exec-once in hyprland)
- `wl-clip-persist` voor clipboard persistentie na afsluiten van vensters
- `clipse` TUI via `Ctrl+Super+V` (alacritty floating terminal)
- Walker clipboard provider als fuzzy alternative

Wayle gebruikt een vaste Tokyo Night palette (bg/surface/elevated/fg/primary) en Inter als font. Fuzzel heeft een INI-gebaseerde stylingconfig die exact deze kleuren en border-radius kan repliceren.

## Goals / Non-Goals

**Goals:**
- Visuele clipboard picker die aansluit bij wayle's stijl
- cliphist als lichtgewichte daemon naast clipse
- Keybinding `Ctrl+Super+C` voor snelle toegang
- Geen breaking change aan bestaande clipse TUI

**Non-Goals:**
- clipse verwijderen of vervangen
- Fuzzel als algemene app launcher inzetten (walker blijft primair)
- Afbeeldingen in clipboard picker tonen

## Decisions

### cliphist als history backend naast clipse

cliphist slaat history op als pipe-vriendelijke lijsten, ideaal voor `fuzzel --dmenu`. clipse is een TUI die direct interactief is maar niet pipe-vriendelijk. Beide kunnen parallel draaien omdat ze allebei naar `wl-paste --watch` luisteren via aparte processes.

**Alternatief**: Walker clipboard provider — al aanwezig maar niet apart activeerbaar via keybinding zonder hele Walker te openen.

### Fuzzel als picker UI

Fuzzel heeft een rijkere styling API dan wofi (border-radius, kleuren per element) en is lichter dan rofi. Het INI-formaat mapt direct op de wayle CSS custom properties.

**Alternatief**: `wofi --dmenu` — minder styling opties, geen border-radius.

### Fuzzel config als apart home-manager bestand

`home/hyprland/fuzzel.nix` als apart bestand, geïmporteerd in `default.nix`. Consistent met bestaande structuur (walker.nix, wayle.nix als aparte bestanden).

### Wayle palette mapping naar fuzzel colors

| Wayle token   | Hex       | Fuzzel gebruik           |
|---------------|-----------|--------------------------|
| bg            | `#16161e` | `background`             |
| surface       | `#1a1b26` | input background (via bg)|
| elevated      | `#292e42` | `selection`              |
| fg            | `#c0caf5` | `text`, `selection-text` |
| primary       | `#7aa2f7` | `match`, `border`        |

Fuzzel kleuren worden opgegeven als 8-char hex zonder `#` (RRGGBBAA, alpha `ff` = volledig opaque).

## Risks / Trade-offs

- [cliphist en clipse draaien beide] → beide luisteren naar clipboard events; minimale overhead, geen conflict
- [Fuzzel config niet dynamisch gekoppeld aan wayle palette] → bij palette wijziging moet fuzzel.nix handmatig bijgewerkt worden
- [Ctrl+Super+C nog niet in gebruik] → veilig om te gebruiken, geen conflict met bestaande bindings
