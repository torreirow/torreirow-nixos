## 1. wayle-ipc: D-Bus proxy uitbreiden

- [ ] 1.1 Voeg `osd_show(label: &str, icon: &str, value: &str, fraction: f64)` toe aan `ShellIpc` trait in `crates/wayle-ipc/src/shell_ipc.rs`

## 2. wayle-shell: IPC state en handler

- [ ] 2.1 Voeg `osd_trigger: Property<Option<OsdEvent>>` toe aan `ShellIpcState` in `crates/wayle-shell/src/services/shell_ipc/state.rs`
- [ ] 2.2 Implementeer `osd_show` in `ShellIpcDaemon` (`crates/wayle-shell/src/services/shell_ipc/dbus.rs`): converteer parameters naar `OsdEvent` en zet `osd_trigger`
- [ ] 2.3 Geef `osd_trigger` door via `ShellIpcService::state()` zodat de OSD er bij kan

## 3. wayle-shell: OSD watcher

- [ ] 3.1 Voeg watcher toe aan `crates/wayle-shell/src/shell/osd/watchers.rs` die luistert op `state.osd_trigger` en `OsdCmd` stuurt naar de OSD component
- [ ] 3.2 Voeg `OsdCmd::ExternalEvent(OsdEvent)` variant toe in `messages.rs` en handel die af in `update_cmd` van de OSD component

## 4. wayle CLI: osd subcommand

- [ ] 4.1 Maak `wayle/src/cli/osd/` directory met `mod.rs` en `show.rs`
- [ ] 4.2 Implementeer `show.rs`: parse CLI args, verbind via D-Bus proxy, roep `osd_show` aan
- [ ] 4.3 Registreer `osd` subcommand in de wayle CLI root (`wayle/src/cli/mod.rs` of `main.rs`)

## 5. torreirow-nixos: font-scale script aanpassen

- [ ] 5.1 Vervang `notify-send` in het font-scale script in `home/hyprland/bindings.nix` door `wayle osd show` met passende `--label`, `--icon`, `--value` en `--fraction`
