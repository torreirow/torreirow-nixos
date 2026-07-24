## 1. Messages aanpassen

- [x] 1.1 In `messages.rs`: `QuickActionsInput::PowerSaverToggled` hernoemen naar `PowerProfileCycled`
- [x] 1.2 In `messages.rs`: `QuickActionsCmd::PowerSaverChanged(bool)` vervangen door `PowerProfileChanged(PowerProfile)` (import `PowerProfile` toevoegen)

## 2. Watcher bijwerken

- [x] 2.1 In `watchers.rs`: `spawn_power_profile_watcher` aanpassen zodat hij `PowerProfileChanged(profile.get())` stuurt in plaats van `PowerSaverChanged(is_saver)`

## 3. Methods herschrijven

- [x] 3.1 In `methods.rs`: `toggle_power_saver()` vervangen door `cycle_power_profile()` met cycle-logica: `PowerSaver → Balanced → Performance (als beschikbaar) → PowerSaver`
- [x] 3.2 In `methods.rs`: `self.has_performance` gebruiken om te bepalen of Performance in de cycle zit

## 4. Component state en view bijwerken

- [x] 4.1 In `mod.rs`: `power_saver_active: bool` vervangen door `active_profile: PowerProfile` in de struct
- [x] 4.2 In `mod.rs`: `has_performance: bool` toevoegen aan de struct
- [x] 4.3 In `mod.rs` `init()`: `active_profile` initialiseren vanuit `current_pp` service; `has_performance` bepalen uit `available_profiles`
- [x] 4.4 In `mod.rs` `view!`: knop-icoon dynamisch via `match model.active_profile` (leaf/scale/rocket)
- [x] 4.5 In `mod.rs` `view!`: knop-label dynamisch via `match model.active_profile` (i18n keys)
- [x] 4.6 In `mod.rs` `view!`: `set_class_active: ("active", model.active_profile != PowerProfile::Balanced)`
- [x] 4.7 In `mod.rs` `update()`: `PowerSaverToggled` → `PowerProfileCycled`, aanroep naar `cycle_power_profile()`
- [x] 4.8 In `mod.rs` `update_cmd()`: `PowerSaverChanged(active)` → `PowerProfileChanged(profile)` handler; `has_performance` bijwerken in `PowerProfilesReady`

## 5. i18n bijwerken

- [x] 5.1 In `locales/en-US/dropdowns/_dashboard.ftl`: bestaande `dropdown-dashboard-battery-profile-*` keys hergebruikt (zelfde waarden, geen nieuwe keys nodig)
- [x] 5.2 In `locales/fr/dropdowns/_dashboard.ftl`: bestaande `dropdown-dashboard-battery-profile-*` keys hergebruikt (reeds aanwezig)

## 6. Compileren en testen

- [x] 6.1 Wayle fork compileren: `cargo build` in `/home/wtoorren/data/git/torreirow/wayle`
- [x] 6.2 Overlay hash/src bijwerken in `overlays/wayle.nix` in torreirow-nixos repo
- [x] 6.3 `nixos-rebuild switch --flake .#lobos` uitvoeren
- [x] 6.4 Handmatig testen: klikken door alle drie profiles en controleren of icoon, label en active-staat correct wisselen
- [x] 6.5 Controleren of externe profielwijziging (via battery dropdown) de dashboard knop ook bijwerkt
