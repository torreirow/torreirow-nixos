## Context

Wayle's OSD is een relm4 GTK4 component (`Controller<Osd>`) dat leeft in de Shell. Het reageert op interne `OsdCmd` berichten die worden gestuurd door watchers op PipeWire, backlight en evdev events. Er is geen ingang van buitenaf.

IPC werkt via D-Bus (`com.wayle.Shell1`). Bestaande commando's (bar hide/show/toggle) gebruiken een `ShellIpcState` met reactive `Property` velden. Shell-componenten abonneren zich op deze properties en reageren op wijzigingen.

De wayle fork bevindt zich in `/home/wtoorren/data/git/torreirow/wayle`. De nixos-config heeft een overlay (`overlays/wayle.nix`) die de fork gebruikt.

## Goals / Non-Goals

**Goals:**
- `wayle osd show` commando dat een OSD toont identiek aan volume/brightness OSD
- Slider-variant (met progress bar) wanneer `--fraction` meegegeven wordt
- Label-only variant (toggle-stijl) zonder `--fraction`
- Font-scale script gebruikt `wayle osd show` i.p.v. `notify-send`

**Non-Goals:**
- Aanpassen van OSD styling (volgt bestaande wayle theming)
- Persistente OSD state (eenmalige trigger, auto-dismiss zoals volume)
- Meerdere gelijktijdige custom OSD's

## Decisions

### Reactive Property als trigger (niet directe ComponentSender)

De OSD component heeft `type Input = ()` — er is geen extern input-kanaal. De schone route is een `Property<Option<OsdEvent>>` in `ShellIpcState`. De OSD voegt een watcher toe op deze property, net zoals hij PipeWire-events bewaakt. Wijziging → OSD toont.

Alternatief: `Input` van Osd uitbreiden met een extern event type. Dat vereist meer ingrijpende wijzigingen in de OSD component en doorbreekt de huidige architectuur.

### Bestaande `OsdEvent` enum hergebruiken

`OsdEvent::Slider { label, icon, percentage, muted }` en `OsdEvent::Toggle { label, icon, active }` zijn al aanwezig. Voor `wayle osd show`:
- Met `--fraction`: `OsdEvent::Slider` met `percentage = fraction * 100.0`, `muted = false`
- Zonder `--fraction`: `OsdEvent::Toggle` met `active = true`

`--value` gaat in `label` van de slider-header (het bestaande `osd-value` label toont dit).

### D-Bus methode signature

```
osd_show(label: &str, icon: &str, value: &str, fraction: f64) -> Result<()>
```

`fraction = -1.0` als sentinel voor "geen progress bar" (D-Bus heeft geen Option<f64>). Shell-kant converteert naar de juiste `OsdEvent` variant.

## Risks / Trade-offs

- [OsdEvent::Slider verwacht percentage 0–100, niet 0.0–1.0] → Conversie in D-Bus handler: `fraction * 100.0`
- [Property<Option<OsdEvent>> triggert ook bij None] → Watcher checkt op `Some(_)` voordat hij OSD toont
- [Wayle fork rebuild vereist bij elke config change] → Bestaand gedrag, geen nieuwe overhead

## Migration Plan

1. Wayle fork wijzigen (Rust) → lokaal bouwen + testen
2. `overlays/wayle.nix` pakt automatisch de nieuwe fork source
3. `home-manager switch` activeert het nieuwe `wayle osd show` commando
4. `bindings.nix` font-scale script aanpassen van `notify-send` naar `wayle osd show`
