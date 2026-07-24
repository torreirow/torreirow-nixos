## Context

Wayle heeft een uitgebreid dropdown systeem waarbij elk dropdown-type een GTK4/Relm4 `Component` is dat als `gtk::Popover` wordt gerenderd. Dropdowns worden geregistreerd via een macro in `dropdowns/mod.rs` en getriggerd via `ClickAction::Dropdown("naam")` in de config.

De planify dropdown is het directe referentiepatroon: een lijst van items uit een externe databron, getoond in een scrollbare `gtk::Box` met rijen. Het enige verschil met clipboard is de databron (`cliphist list` subprocess vs SQLite) en de interactie (kopieer naar clipboard vs navigeer naar app).

Huidige clipboard setup:
- `cliphist` draait als daemon via `wl-paste --watch cliphist store`
- `Ctrl+Super+C` triggert al de fuzzel picker (bestaande keybinding)
- Dit is complementair: bar-icoon voor muis, fuzzel voor keyboard

## Goals / Non-Goals

**Goals:**
- Native wayle dropdown voor clipboard history (muis-toegankelijk via bar)
- Klik op entry → item in clipboard, dropdown sluit
- Refresh op popover open (altijd actuele lijst)
- Visueel consistent met bestaande dropdowns (zelfde palette, rounding, header)

**Non-Goals:**
- Zoekfunctie / filtering in de dropdown (dat is fuzzel's rol)
- Afbeeldingen of binaire clipboard entries tonen
- Clipboard entries verwijderen vanuit de dropdown
- Eigen config schema (geen `[modules.clipboard]` nodig — custom module volstaat)

## Decisions

### Refresh op map signal, niet polling

Clipboard wijzigt continu terwijl de dropdown gesloten is. Polling zou onnodige overhead geven. De `gtk::Popover` heeft een `connect_map` signal dat vuurt precies als de popover zichtbaar wordt — ideaal voor een one-shot `cliphist list` refresh.

**Alternatief**: 1s poll timer — overbodig en duurder dan on-demand load.

### gtk::ListBox i.p.v. gtk::Box voor rijen

`gtk::ListBox` geeft automatisch hover-highlight en `row-activated` signal per rij, wat precies nodig is voor klik-om-te-kopiëren. Planify gebruikt `gtk::Box` omdat taken niet interactief zijn; clipboard entries wel.

**Alternatief**: `gtk::Box` met individuele `connect_clicked` per label — werkt maar minder idiomatisch voor selecteerbare lijsten.

### Subprocess via tokio::process::Command in update_cmd

De `map` signal handler stuurt een `Refresh` bericht. Het component spawnt dan een async `Command::new("cliphist").arg("list")` in `update_cmd` via `sender.command(...)`. Output wordt geparsed als tab-separated `id\tpreview`.

### Geen nieuwe config schema

Het clipboard icoon wordt als `[[modules.custom]]` in `wayle.nix` geconfigureerd — dezelfde aanpak als solidtime en planify. Geen Rust config struct nodig.

### Kopieer actie: shell pipe via sh -c

`cliphist decode` verwacht de volledige `id\tcontent` string op stdin. De kopieeractie wordt:
```bash
printf '%s' "1\thello world" | cliphist decode | wl-copy
```
Uitgevoerd via `process::run` (wayle's bestaande helper) of direct `std::process::Command`.

## Risks / Trade-offs

- [cliphist niet geïnstalleerd of niet in PATH] → dropdown toont lege lijst met fallback label "Clipboard niet beschikbaar"; geen crash
- [Lange clipboard entries] → preview trunceren op 60 chars via `set_max_width_chars`
- [Binaire entries in cliphist] → cliphist list toont ze als `[binary]` of hex — tonen als disabled rij of overslaan op `\0` bytes in preview
- [Wayle fork divergeert van upstream] → verandering is geïsoleerd in één nieuwe directory; geen upstream bestanden gewijzigd behalve `mod.rs` registratie
