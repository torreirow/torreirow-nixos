## Context

Wayle is een Rust/GTK4 bar voor Hyprland, gebouwd met het Relm4 framework (model-update-view patroon). Het dashboard bevat een "Quick Actions" sectie met een 3×2 grid van toggle-knoppen. De huidige "Power Saver" knop (positie [2,1]) is een boolean toggle: aan = `PowerSaver`, uit = `Balanced`. De knop roept `toggle_power_saver()` aan in `methods.rs`, die via een Relm4 oneshot-command de D-Bus `PowerProfilesWayleProxy` aanspreekt.

De battery dropdown heeft wél een volwaardige 3-weg segmented control (`PowerProfileSection` component), inclusief `has_performance` vlag en availability-watchers. De dashboard quick actions mist die kennis van beschikbare profielen.

## Goals / Non-Goals

**Goals:**
- Cycle-knop die door alle beschikbare power profiles fietst (PowerSaver → Balanced → Performance → PowerSaver)
- Knop toont dynamisch het actieve profiel: icoon + label wisselt mee
- Balanced = "uit-staat" visueel; PowerSaver/Performance = "aan-staat"
- Graceful degradatie: als Performance niet beschikbaar is, cycle alleen tussen PowerSaver en Balanced
- i18n: profielnamen vertaalbaar via FTL keys

**Non-Goals:**
- De battery dropdown aanpassen (die werkt al correct)
- Een nieuwe UI-layout (grid blijft 3×2)
- Availability-watcher voor individuele profielen (we lezen `available_profiles` eenmalig bij `PowerProfilesReady`)

## Decisions

### 1. State: `power_saver_active: bool` → `active_profile: PowerProfile`

`QuickActionsSection` hield alleen bij of power saver actief was. We vervangen dit door het volledige `PowerProfile` enum. Dit maakt icoon/label/active-class logica direct afleidbaar zonder extra flags.

**Alternatief overwogen:** Twee booleans `power_saver_active` + `performance_active` toevoegen. Afgewezen: redundant en foutgevoelig (twee booleans kunnen inconsistent worden).

### 2. `has_performance: bool` bijhouden in QuickActionsSection

De cycle-logica moet weten of Performance beschikbaar is op dit systeem. We lezen `available_profiles` uit de `PowerProfilesService` bij `PowerProfilesReady` en `ServiceAvailable` events, net zoals `PowerProfileSection` in de battery dropdown dat doet.

**Alternatief overwogen:** Altijd door alle drie profielen fietsen en de D-Bus error afvangen. Afgewezen: stille failures zijn slechte UX.

### 3. Cycle volgorde: PowerSaver → Balanced → Performance → PowerSaver

Logische escalatie van "zuinig" naar "krachtig". Balanced is het middenpunt. Dit is ook de volgorde die de battery dropdown visueel toont (links → rechts).

### 4. Watcher stuurt `PowerProfileChanged(PowerProfile)` in plaats van `PowerSaverChanged(bool)`

De watcher in `watchers.rs` stuurt nu het volledige profiel. Dit elimineert de informatievermindering (bool → enum) die voorheen plaatsvond en maakt de handler eenvoudiger.

### 5. i18n: drie aparte keys per profiel

```
dropdown-dashboard-power-profile-saver = Power Saver
dropdown-dashboard-power-profile-balanced = Balanced
dropdown-dashboard-power-profile-performance = Performance
```

De bestaande key `dropdown-dashboard-power-saver` blijft bestaan voor backwards-compat (wordt niet verwijderd, maar niet meer gebruikt door de knop).

**Alternatief overwogen:** Bestaande battery dropdown keys hergebruiken (`dropdown-battery-profile-saver` etc.). Afgewezen: die keys zitten in een andere crate (`wayle-shell/locales/` maar ander FTL bestand) en zijn conceptueel van de battery dropdown, niet van de quick actions.

## Risks / Trade-offs

- **Performance niet overal beschikbaar** → Mitigatie: `has_performance` flag; cycle slaat Performance over als false
- **D-Bus set_active_profile kan falen** → Zelfde afhandeling als huidige `toggle_power_saver`: warn! log, UI toont toch nieuw profiel (optimistic update via `ProfileChanged` cmd). Dit gedrag was al zo.
- **Relm4 `#[watch]` macro met match-expressie** → Icoon en label in de view! macro vereisen een `match`-expressie die `PowerProfile` enum matcht. Dit is standaard Relm4 patroon, geen risico.

## Migration Plan

1. Wijzigingen in wayle fork implementeren en compileren
2. `overlays/wayle.nix` hash bijwerken (of `src` aanpassen naar nieuwe commit)
3. `nixos-rebuild switch --flake .#lobos` uitvoeren
4. Handmatig testen: klikken op de knop en controleren of profiel wisselt

Rollback: vorige Git commit van wayle fork restoren en overlay hash terugdraaien.
