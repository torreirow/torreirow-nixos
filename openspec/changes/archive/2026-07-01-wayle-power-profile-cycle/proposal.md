## Why

De "Power Saver" quick action knop in het Wayle dashboard is een simpele on/off toggle die alleen tussen `PowerSaver` en `Balanced` wisselt. Daardoor is `Performance` mode niet instelbaar vanuit het dashboard — de gebruiker moet hiervoor de aparte battery dropdown openen.

## What Changes

- De "Power Saver" knop in de Quick Actions sectie van het dashboard wordt vervangen door een cycle-knop die door alle beschikbare power profiles fietst
- Klikken gaat in volgorde: `PowerSaver → Balanced → Performance → PowerSaver`
- Als Performance niet beschikbaar is op het systeem: `PowerSaver ↔ Balanced`
- Het icoon en label van de knop tonen dynamisch het **huidige** actieve profiel
- Bij `Balanced` heeft de knop de "uit-staat" (geen active CSS class); bij `PowerSaver` of `Performance` de "aan-staat"
- Iconen: PowerSaver = `ld-leaf-symbolic`, Balanced = `ld-scale-symbolic`, Performance = `ld-rocket-symbolic`

## Capabilities

### New Capabilities

- `power-profile-cycle`: Cycle-knop in dashboard quick actions die door alle drie power profiles fietst, met dynamisch icoon en label op basis van het actieve profiel

### Modified Capabilities

_(geen bestaande specs geraakt)_

## Impact

- **wayle fork** (`/home/wtoorren/data/git/torreirow/wayle`):
  - `crates/wayle-shell/src/shell/bar/dropdowns/dashboard/quick_actions/` — alle vier bestanden (`messages.rs`, `methods.rs`, `mod.rs`, `watchers.rs`)
  - `crates/wayle-shell/locales/en-US/dropdowns/_dashboard.ftl` — nieuwe i18n keys voor profielnamen
  - `crates/wayle-shell/locales/fr/dropdowns/_dashboard.ftl` — Franse vertalingen
- **torreirow-nixos** (`overlays/wayle.nix`) — overlay bijwerken na herbouw wayle fork
