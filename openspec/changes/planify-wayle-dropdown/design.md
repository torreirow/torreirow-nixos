## Context

Wayle dropdowns zijn GTK4/relm4 componenten geregistreerd in `dropdowns/mod.rs`.
Elke dropdown implementeert `DropdownFactory` en wordt lazy aangemaakt bij de
eerste klik. Planify slaat taken op in een lokale SQLite database op
`~/.local/share/io.github.alainm23.planify/database.db`. `rusqlite` staat al
in de workspace `Cargo.toml` (feature `bundled`), maar is nog niet in gebruik
in `wayle-shell`.

Bestaand patroon: calendar dropdown — geen externe service, leest lokale data,
polling via `tokio::time::sleep`. Dit is het dichtstbijzijnde voorbeeld.

## Goals / Non-Goals

**Goals:**
- Taken tonen uit één configureerbaar Planify-project
- Badge toont totaal open taken, dropdown groepeert op urgentie
- DB-pad en projectnaam configureerbaar met zinvolle defaults
- Polling (niet watch) op de SQLite file — eenvoudig en voldoende

**Non-Goals:**
- Taken aanmaken of voltooien vanuit de dropdown
- Meerdere projecten tegelijk tonen
- Planify API of cloud sync — alleen lokale DB

## Decisions

### 1. SQLite lezen via rusqlite in de GTK thread vs. tokio spawn_blocking

**Keuze:** `tokio::task::spawn_blocking` voor de DB-query, resultaat terugsturen
via `ComponentSender::command`.

**Waarom:** SQLite I/O blokkeert. De GTK main loop mag niet blokkeren. Het
calendar-patroon gebruikt `sender.command(|out, shutdown| async move { ... })`
— zelfde aanpak, maar met `spawn_blocking` voor de sync SQLite-aanroep.

### 2. Project identificeren via naam, niet ID

**Keuze:** Config-veld `project = "TN-ToDo"` (naam). Bij init opzoeken naar ID
via `SELECT id FROM Projects WHERE name = ? AND is_deleted = 0`.

**Waarom:** UUID's zijn niet leesbaar voor de gebruiker. Naam is stabiel genoeg
— Planify laat hernoemen toe maar dat is zeldzaam.

### 3. Groepering van taken

Drie secties, in volgorde:
1. **Verlopen** — `due.date < vandaag`, rood gestyled
2. **Vandaag** — `due.date = vandaag` + taken zonder datum (geen deadline = behandeld als vandaag)
3. **Komend** — `due.date > vandaag`

Taken zonder datum worden altijd in "Vandaag" geplaatst. Badge = COUNT van alle
drie de secties samen (totaal open).

### 4. Polling interval

60 seconden. Planify werkt offline-first, de DB wijzigt alleen als de gebruiker
iets doet. 60s is responsief genoeg zonder onnodige I/O.

### 5. Config schema locatie

Nieuw bestand `crates/wayle-config/src/schemas/modules/planify.rs`, geregistreerd
in `ModulesConfig`. Velden:
- `project: String` (default: `"Inbox"`)
- `db-path: Option<PathBuf>` (default: `None` → runtime XDG pad)

### 6. "Open Planify" knop

In de dropdown-header (rechtsbovenin), als `GhostIconButton` met
`external-link-symbolic`. Activeert Planify via `gtk::gio::AppInfo::launch_default_for_uri`
of shell: `uwsm app -- io.github.alainm23.planify`.

Right-click op de bar-module zelf (via `right-click` in custom module config)
doet hetzelfde.

## Risks / Trade-offs

- **DB-pad hardcoded per gebruiker** → Opgelost via config-veld met default
- **SQLite locked tijdens Planify schrijven** → rusqlite opent read-only
  (`OpenFlags::SQLITE_OPEN_READ_ONLY`), geen lock-conflict
- **Projectnaam wijzigt** → dropdown toont lege lijst met foutmelding in tooltip;
  gebruiker past config aan
- **Planify niet geïnstalleerd** → factory geeft `Some(instance)` terug maar
  DB-pad bestaat niet; component toont "database niet gevonden"

## Migration Plan

1. Wijzigingen in wayle fork committen en nixos overlay rebuilden
2. `wayle.nix` uitbreiden: `[modules.planify]` config + bar layout
3. `home-manager switch` uitvoeren
4. Wayle service herstarten: `systemctl --user restart wayle`

Rollback: `planify` uit bar layout verwijderen.

## Open Questions

_(geen)_
