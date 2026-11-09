## Context

De wayle fork (`/home/wtoorren/data/git/torreirow/wayle`) is een Rust/GTK4 statusbalk gebouwd met het relm4 framework. Modules en dropdowns volgen een vast patroon: elke module heeft `mod.rs` (relm4 Component), `factory.rs` (ModuleFactory/DropdownFactory), `messages.rs` (Init/Msg/Cmd types) en `watchers.rs` (async tokio taken). De `planify` module (recent zelf toegevoegd) is het dichtstbijzijnde model: een externe data source (SQLite) die via subprocess/library wordt bevraagd en zowel een bar knop als een dropdown heeft.

De `soltty` binary (`github.com/torreirow/soltty`, Go CLI) is al aanwezig op het systeem en in de nixos flake. JSON output formaten zijn bekend:
- `soltty current --json` → `{ running: bool, id?, description?, project?, elapsed?, start? }`
- `soltty list projects --json` → `[{ id, name, client_id?, client? }]`
- `soltty list --json --limit N` → array van recente entries
- `soltty start "<desc>" [-p "<project>"] [-y]` → start timer
- `soltty stop` → stop timer

Caspersonn's AGS soltty widget (`lkasper-hyprland/ags/windows/soltty/`) dient als UI referentie.

## Goals / Non-Goals

**Goals:**
- Native `solidtime` bar module en dropdown die volledig geïntegreerd zijn in wayle's bestaande architectuur
- Visuele pariteit met weather/planify dropdowns (zelfde templates, design tokens, CSS aanpak)
- Functionele pariteit met Caspersonn's AGS soltty widget (status, start/stop, project picker, recents)
- `wayle.toml` config via `[modules.solidtime]` en `"solidtime"` in bar layout

**Non-Goals:**
- Live beschrijving bewerken van een lopende timer (soltty heeft geen update commando; stop+herstart is de workaround maar verhoogt complexiteit onevenredig)
- Solidtime API directe integratie (alles via soltty CLI)
- Gedeelde service tussen bar module en dropdown (onafhankelijke polling is voldoende)

## Decisions

### Geen gedeelde SolidtimeService

**Beslissing**: Bar module en dropdown pollen `soltty` onafhankelijk.

**Rationale**: De weather module heeft een gedeelde `WeatherService` omdat meerdere bar instanties en de dropdown dezelfde data behoeven. Voor solidtime is er slechts één bar module en één dropdown; gedeelde state vereist extra plumbing (Arc<Mutex<>>, ShellServices uitbreiden, bootstrap aanpassingen) zonder merkbaar voordeel. Bar module pollt elke 5s; dropdown pollt elke 2s wanneer open. Na een actie (start/stop) refresht de dropdown direct, de bar binnen 5s.

**Alternatief overwogen**: `Arc<SolidtimeState>` gedeeld via `ShellServices` — verworpen vanwege overkill voor één instantie.

### soltty CLI als enige backend

**Beslissing**: Alle data via `tokio::process::Command::new("soltty")`, geen directe HTTP calls.

**Rationale**: soltty is het eigen project van de gebruiker, fully featured, al aanwezig. Directe API calls dupliceren logica die soltty al beheert (authenticatie, workspace ID, error handling). soltty leest credentials van `~/.config/soltty/config.json`.

### Elapsed berekening lokaal, niet via soltty

**Beslissing**: Bar module slaat `start: Option<DateTime<Utc>>` op van de laatste poll en berekent elapsed lokaal elke seconde via een 1s tick watcher.

**Rationale**: `soltty current --json` aanroepen elke seconde zou de Solidtime API onder druk zetten en onnodige latency introduceren. De `start` timestamp verandert niet tijdens een sessie. Maximale drift: 1 seconde per 5s poll cycle.

### gtk::DropDown voor project picker

**Beslissing**: `gtk::DropDown` met `set_enable_search(true)` en `gtk::StringList` als model.

**Rationale**: Caspersonn's inline search panel (custom TSX widget) repliceert wat GTK4 ingebouwd biedt. `gtk::DropDown` met search is native, thema-consistent en vereist geen extra widgets.

### Bestaande `Dropdown`/`DropdownHeader`/`DropdownContent` templates

**Beslissing**: Zelfde GTK4 template widgets gebruiken als calendar/planify/weather.

**Rationale**: Garandeert visuele consistentie zonder eigen CSS te schrijven voor structuur. Alleen module-specifieke stijlen (status card, pulserende dot, field labels) vereisen nieuwe SCSS.

## Risks / Trade-offs

**[Risk] soltty binaire interface verandert** → soltty is eigen project; JSON schema wijzigingen zijn in eigen hand. Mitigatie: JSON velden parsen via `serde_json::Value` met expliciete key lookups zodat ontbrekende velden niet paniceren.

**[Risk] soltty startup latency** → Elke subprocess spawn kost ~10-50ms. Bij 5s polling is dit verwaarloosbaar. Mitigatie: geen.

**[Risk] Dropdown project picker leeg bij soltty fout** → Als `soltty list projects` faalt, blijft de picker leeg maar crasht de UI niet. Mitigatie: placeholder item "No projects" tonen bij lege lijst.

**[Trade-off] Bar module vertraagt max. 5s na stop/start** → Acceptabel; gebruiker ziet directe feedback in de dropdown, bar volgt binnen 5s.

## Migration Plan

1. Implementeer wayle fork changes (wayle-config → wayle-shell → wayle-styling)
2. Build wayle lokaal via Nix overlay (`overlays/wayle.nix` verwijst naar local path)
3. Update `home/hyprland/wayle.nix`: verwijder custom solidtime sectie, voeg `"solidtime"` toe aan bar layout
4. Run `home-manager switch` om de nieuwe wayle te activeren
5. Rollback: zet `custom-solidtime` terug in wayle.nix en gebruik vorige wayle build

## Open Questions

- Welk icoon voor de solidtime bar knop? (`ld-zap-symbolic` is beschikbaar in wayle's icon set als placeholder voor timer/energie; kan later geconfigureerd worden via `[modules.solidtime] icon-name`)
