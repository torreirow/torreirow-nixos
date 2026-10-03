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

### 6. Menu op alle actieve schermen: één fuzzel per output, eigen runtime-dir
*Toegevoegd na de tests, op verzoek van de user.* fuzzel 1.14 neemt een lock op
`$XDG_RUNTIME_DIR/fuzzel-$WAYLAND_DISPLAY.lock` ("fuzzel already running?"), dus een tweede instantie
start niet. Workaround: per output een tijdelijke runtime-dir met een symlink naar de echte
Wayland-socket, en fuzzel daar met `--output=<naam>` starten. De temp-dir staat onder
`$XDG_RUNTIME_DIR`: een Unix-socketpad mag max 108 bytes zijn, en een lange `$TMPDIR` brak dat. De eerste die eindigt (keuze of Escape)
wint, de rest wordt gekilld. Gemirrorde outputs krijgen geen eigen menu, want ze tonen eDP-1 al.
- **Valkuil (gevonden bij de test: geen menu met HDMI aangesloten):** een nieuwe fuzzel pakt de
  toetsenbordfocus en de vorige sluit dan standaard af (rc 1, zonder melding). `wait -n` zag dat als
  "klaar" en killde de andere, dus er bleef geen menu over. Fix: `--no-exit-on-keyboard-focus-loss`,
  en het gefocuste scherm als laatste starten zodat dát het toetsenbord krijgt. Op het andere scherm
  kies je met de muis.
- *Risico:* het omzeilt een bewuste lock en kan breken bij een fuzzel-update. Faalt een instantie
  meteen, dan sluit het hele menu (geen wijziging), dus het faalt veilig.
- *Alternatief: alleen op het externe scherm.* Afgewezen door de user.

### 7. Per-scherm-regels via een tabel, ook in het menu
De TV "CTV CTV 0x00000001" is een 4K-paneel. Hij biedt 1920x1080@60 als preferred aan en 4K maximaal
op 30 Hz (4K@60 niet aangeboden). Op 1080p ziet "Ongeschaald" er klein uit, en de andere TV-standen
hebben overscan (de wayle-bar valt weg). Oorzaak bleek de TV-instelling **EDID 1.4**. Met **EDID 2.0**
biedt de TV 3840x2160@60 als preferred (zelfde beschrijving). Keuze: **3840x2160@60, schaal 2**. Valt
de TV ooit terug op EDID 1.4, dan kiest Hyprland voor een niet-aangeboden mode de dichtstbijzijnde.
- `home/hyprland/external-monitors.nix`: lijst `{ desc, mode, scale }`. `default.nix` maakt er
  `desc:<desc>,<mode>,auto,<scale>`-regels van, plus een vangregel `,preferred,auto,1`. De naamregel
  `HDMI-A-1,preferred,auto,1` vervalt: die zou poort-gebonden zijn en is gelijk aan de vangregel.
- Het script krijgt dezelfde tabel als JSON en bouwt de regel voor het externe scherm op basis van
  `.description`. Zo overschrijft een stand de TV-regel niet met `preferred,auto,1` (de eerdere fout
  in decision 1). Uitgebreid blijft expliciet toepassen, geen `hyprctl reload`: een reload zet ook
  andere runtime-state terug.

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
