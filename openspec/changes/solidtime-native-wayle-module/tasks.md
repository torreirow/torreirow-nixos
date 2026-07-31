## 1. wayle-config: SolidtimeConfig en BarModule variant

- [x] 1.1 Maak `wayle/crates/wayle-config/src/schemas/modules/solidtime.rs` aan met `SolidtimeConfig` struct (icon, label, border, color properties, `left-click` default `"dropdown:solidtime"`) — volg `WeatherConfig` als model
- [x] 1.2 Registreer `SolidtimeConfig` in `wayle/crates/wayle-config/src/schemas/modules/mod.rs`: `pub mod solidtime`, `pub use solidtime::SolidtimeConfig`, voeg `pub solidtime: SolidtimeConfig` toe aan `ModulesConfig`
- [x] 1.3 Voeg `Solidtime` toe aan `BarModule` enum in `wayle/crates/wayle-config/src/schemas/bar/types/mod.rs`
- [x] 1.4 Voeg `"solidtime"` toe aan `BUILTIN_MODULES`, `to_kebab_case` en `from_kebab_case` in `types/mod.rs`

## 2. wayle-shell: solidtime bar module

- [x] 2.1 Maak directory `wayle/crates/wayle-shell/src/shell/bar/modules/solidtime/`
- [x] 2.2 Maak `messages.rs` aan: `SolidtimeInit` (met `settings`, `config`, `dropdowns`), `SolidtimeMsg` (LeftClick/RightClick/MiddleClick/ScrollUp/ScrollDown), `SolidtimeCmd` (StatusUpdate { running, start, description, project }, Tick, ScaleChanged)
- [x] 2.3 Maak `watchers.rs` aan: 5s poll watcher die `soltty current --json` aanroept en `StatusUpdate` emit; 1s tick watcher die `Tick` emit
- [x] 2.4 Maak `mod.rs` aan: relm4 `Component` met `BarButton`, verwerkt `StatusUpdate` (sla `running` + `start: Option<DateTime<Utc>>` op, update label), verwerkt `Tick` (bereken HH:MM:SS van `start`, emit `BarButtonInput::SetLabel`), verwerkt click messages via `dropdowns::dispatch_click`
- [x] 2.5 Maak `factory.rs` aan: implementeer `ModuleFactory` — volg `weather/factory.rs` exact
- [x] 2.6 Registreer module in `wayle/crates/wayle-shell/src/shell/bar/modules/mod.rs`: `mod solidtime`, `Solidtime => solidtime::Factory` in `register_modules!`

## 3. wayle-shell: solidtime dropdown

- [x] 3.1 Maak directory `wayle/crates/wayle-shell/src/shell/bar/dropdowns/solidtime/`
- [x] 3.2 Maak `messages.rs` aan: `SolidtimeDropdownInit`, `SolidtimeDropdownMsg` (Refresh, StartTimer, StopTimer, ProjectSelected(u32)), `SolidtimeDropdownCmd` (StatusUpdate { running, start, description, project, connected }, Tick, Projects(Vec<ProjectEntry>), Recent(Vec<RecentEntry>), ScaleChanged, ActionDone)
- [x] 3.3 Maak `watchers.rs` aan: 2s poll watcher voor `soltty current --json`; 1s tick watcher; bij `ActionDone` direct re-poll; helper functie `run_soltty(args) -> Option<Value>` via `tokio::process::Command`
- [x] 3.4 Maak `mod.rs` aan met relm4 view! layout: `gtk::Popover` met `Dropdown`/`DropdownHeader`/`DropdownContent` templates; statuskaart (status dot, label, subtext, elapsed `gtk::Label`); description `gtk::Entry`; project `gtk::DropDown` met `StringList` en `set_enable_search(true)`; start/stop `gtk::Button`; recent entries `gtk::Box` met dynamische rows
- [x] 3.5 Implementeer `update_cmd` in dropdown `mod.rs`: verwerk `StatusUpdate` (update running/start/description/project state en labels), `Tick` (herbereken elapsed), `Projects` (vul `StringList`), `Recent` (herbouw recent box), `ActionDone` (direct watchers triggeren)
- [x] 3.6 Implementeer `update` in dropdown `mod.rs`: verwerk `StartTimer` (spawn `soltty start`), `StopTimer` (spawn `soltty stop`), `Refresh` (directe poll), `ProjectSelected`
- [x] 3.7 Maak `factory.rs` aan: implementeer `DropdownFactory` — volg `planify/factory.rs` exact
- [x] 3.8 Registreer dropdown in `wayle/crates/wayle-shell/src/shell/bar/dropdowns/mod.rs`: `mod solidtime`, `"solidtime" => solidtime::Factory` in `register_dropdowns!`

## 4. wayle-styling: solidtime SCSS

- [x] 4.1 Maak `wayle/crates/wayle-styling/scss/modules/solidtime_dropdown/_index.scss` aan met stijlen voor: `.solidtime-status` (idle/running varianten), `.solidtime-status-dot` met `@keyframes solidtime-pulse` animatie, `.solidtime-elapsed`, `.solidtime-field-label`, `.solidtime-conn-dot` (ok/bad varianten), `.solidtime-recent-row` — gebruik wayle design tokens (`--fg-default`, `--space-sm`, etc.)
- [x] 4.2 Voeg `@use 'solidtime_dropdown' as *;` toe aan `wayle/crates/wayle-styling/scss/modules/_index.scss`

## 5. Wayle fork builden en testen

- [x] 5.1 Compileer wayle fork lokaal: `cd /home/wtoorren/data/git/torreirow/wayle && cargo build 2>&1` — fix compiler errors
- [x] 5.2 Verifieer dat `cargo build` succesvol is zonder warnings over ongebruikte imports

## 6. torreirow-nixos: wayle.nix aanpassen

- [x] 6.1 Verwijder de `solidtime-waybar-input` parameter uit de module signature van `home/hyprland/wayle.nix`
- [x] 6.2 Verwijder de `solidtime-waybar-pkg` en `solidtime-timer` let-bindings uit `wayle.nix`
- [x] 6.3 Vervang `"custom-solidtime"` door `"solidtime"` in de `center` bar layout array
- [x] 6.4 Verwijder de volledige `[[modules.custom]]` solidtime sectie (id, command, interval-ms, format, tooltip-format, label-show, icon-show, left-click)
- [x] 6.5 Verwijder `solidtime-waybar-input` uit de module signature van `wayle.nix` (het extraSpecialArgs arg blijft in flake.nix voor waybar.nix compatibiliteit)

## 7. NixOS rebuild en verificatie

- [x] 7.1 Run `home-manager switch --flake .#wtoorren@linuxdesktop --extra-experimental-features nix-command -b backup-$(date +%s) --impure` en fix eventuele Nix evaluatie fouten
- [ ] 7.2 Verifieer dat de solidtime bar knop verschijnt in de wayle balk op de juiste positie
- [ ] 7.3 Verifieer dat klikken op de bar knop de solidtime dropdown opent
- [ ] 7.4 Verifieer dat de dropdown projecten laadt, een timer kan starten en stoppen, en de bar knop bijwerkt
