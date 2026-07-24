## 1. wayle-config: config schema

- [x] 1.1 Maak `crates/wayle-config/src/schemas/modules/planify.rs` met `PlanifyConfig` struct (`project: String`, `db-path: Option<PathBuf>`)
- [x] 1.2 Registreer `PlanifyConfig` in `ModulesConfig` (modules/mod.rs)

## 2. wayle-shell: dependency

- [x] 2.1 Voeg `rusqlite.workspace = true` toe aan `crates/wayle-shell/Cargo.toml`

## 3. wayle-shell: planify dropdown module

- [x] 3.1 Maak directory `crates/wayle-shell/src/shell/bar/dropdowns/planify/`
- [x] 3.2 Schrijf `messages.rs` — `PlanifyDropdownInit`, `PlanifyDropdownMsg`, `PlanifyDropdownCmd`, `PlanifyTask` struct
- [x] 3.3 Schrijf `helpers.rs` — SQLite query functie die taken groepeert in (verlopen, vandaag, komend)
- [x] 3.4 Schrijf `watchers.rs` — 60s polling timer die `Cmd::Refresh` stuurt
- [x] 3.5 Schrijf `task_item.rs` — helper functie `make_task_row` in mod.rs (geen apart FactoryComponent)
- [x] 3.6 Schrijf `mod.rs` — hoofdcomponent met GTK view (header, drie secties, scrollable content)
- [x] 3.7 Schrijf `factory.rs` — `DropdownFactory` impl die config leest en component lanceert

## 4. wayle-shell: registratie

- [x] 4.1 Voeg `mod planify;` en `"planify" => planify::Factory` toe aan `dropdowns/mod.rs`

## 5. Compilatie & testen

- [x] 5.1 Compileer wayle fork: `cargo build` in wayle repo
- [ ] 5.2 Verifieer dat dropdown zichtbaar is bij `left-click = "dropdown:planify"`
- [ ] 5.3 Controleer badge-telling klopt met DB inhoud
- [ ] 5.4 Controleer groepering: verlopen rood, vandaag normaal, komend met datum

## 6. NixOS config (wayle.nix)

- [x] 6.1 Voeg `[modules.planify]` toe aan `config.toml` in `wayle.nix` (project + optioneel db-path)
- [x] 6.2 Voeg `"custom-planify"` toe aan bar layout (right-side, naast systray)
- [x] 6.3 Voeg `[[modules.custom]]` blok toe met `left-click = "dropdown:planify"` en `right-click` voor Planify openen

## 7. Nixos rebuild & verificatie

- [x] 7.1 Voer `home-manager switch` uit
- [x] 7.2 Herstart wayle: `systemctl --user restart wayle`
- [ ] 7.3 Verifieer badge en dropdown werken correct in de bar
