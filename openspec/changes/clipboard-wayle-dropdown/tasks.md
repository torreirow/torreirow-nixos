## 1. Rust component aanmaken

- [x] 1.1 Maak directory `crates/wayle-shell/src/shell/bar/dropdowns/clipboard/` in de wayle fork
- [x] 1.2 Maak `messages.rs` aan: `ClipboardEntry { id: String, preview: String }`, `ClipboardDropdownInit`, `ClipboardDropdownMsg { Refresh, EntrySelected(ClipboardEntry) }`, `ClipboardDropdownCmd { Entries(Vec<ClipboardEntry>), ClearAndClose }`
- [x] 1.3 Maak `helpers.rs` aan: `load_entries() -> Vec<ClipboardEntry>` via `Command::new("cliphist").arg("list")`, parse tab-separated output, trunceer preview op 60 chars
- [x] 1.4 Maak `mod.rs` aan: GTK4/Relm4 `Component` als `gtk::Popover` met `DropdownHeader` (icoon + label "Clipboard"), `DropdownContent` met `gtk::ListBox`, entries als `gtk::ListBoxRow`
- [x] 1.5 Implementeer `connect_map` op de popover → stuurt `ClipboardDropdownMsg::Refresh`
- [x] 1.6 Implementeer `row-activated` op ListBox → stuurt `EntrySelected`, voert `printf '%s' "id\tcontent" | cliphist decode | wl-copy` uit en sluit popover
- [x] 1.7 Maak `factory.rs` aan: `pub(crate) struct Factory` die `DropdownFactory` implementeert (identiek aan planify factory)
- [x] 1.8 Maak `mod.rs` in clipboard dir: re-exporteer `Factory`, verbind submodules

## 2. Registratie in wayle-shell

- [x] 2.1 Voeg `mod clipboard;` toe aan `crates/wayle-shell/src/shell/bar/dropdowns/mod.rs`
- [x] 2.2 Voeg `"clipboard" => clipboard::Factory,` toe aan de `register_dropdowns!` macro

## 3. Compilatie en overlays

- [x] 3.1 Compileer de wayle fork: `cargo build` vanuit `/home/wtoorren/data/git/torreirow/wayle/` en fix eventuele compile-errors
- [x] 3.2 Update `overlays/wayle.nix` met nieuwe git hash/rev van de fork zodat nixos de nieuwe binary pakt

## 4. wayle.nix configuratie

- [x] 4.1 Voeg `[[modules.custom]]` blok toe aan `home/hyprland/wayle.nix` voor clipboard module: `id = "clipboard"`, `icon-name = "edit-copy-symbolic"`, `left-click = "dropdown:clipboard"`, `label-show = false`, `icon-show = true`
- [x] 4.2 Voeg `"custom-clipboard"` toe aan de bar layout `right = [...]` naast `"custom-planify"`

## 5. Verificatie

- [x] 5.1 Voer `home-manager switch` uit en herstart wayle (`systemctl --user restart wayle`)
- [x] 5.2 Verifieer dat het clipboard icoon zichtbaar is in de bar
- [x] 5.3 Kopieer tekst, klik op icoon, selecteer entry uit dropdown en verifieer dat het in clipboard staat
