## Why

De wayle OSD reageert alleen op interne events (PipeWire, backlight, evdev). Er is geen manier om vanuit een extern script een OSD te tonen — waardoor de font-scale keybindings terugvallen op `notify-send` in plaats van de visueel consistente OSD die volume en brightness gebruiken.

## What Changes

- Nieuw `wayle osd show` CLI subcommand met parameters `--label`, `--icon`, `--value` (optioneel), `--fraction` (optioneel 0.0–1.0)
- Nieuwe `osd_show` methode op het `com.wayle.Shell1` D-Bus interface
- Reactive `Property<Option<OsdEvent>>` in `ShellIpcState` die de OSD triggert
- OSD component krijgt een watcher op deze property — toont slider (met fraction) of label-only OSD

## Capabilities

### New Capabilities

- `osd-show-command`: Extern aanroepbaar OSD commando via `wayle osd show`

### Modified Capabilities

## Impact

- `crates/wayle-ipc/src/shell_ipc.rs` — `osd_show` methode toevoegen aan D-Bus proxy trait
- `crates/wayle-shell/src/services/shell_ipc/dbus.rs` — `osd_show` handler implementeren
- `crates/wayle-shell/src/services/shell_ipc/state.rs` — `osd_trigger` property toevoegen
- `crates/wayle-shell/src/shell/osd/` — watcher op `osd_trigger` property
- `wayle/src/cli/` — nieuwe `osd` subcommand met `show` actie
- `torreirow-nixos`: `home/hyprland/bindings.nix` font-scale script aanpassen van `notify-send` naar `wayle osd show`
