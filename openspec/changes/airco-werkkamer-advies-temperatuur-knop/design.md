## Context

De airco werkkamer (`climate.airco_werkkamer_zolder`) wordt bediend via het HA "Airco" dashboard. De buitentemperatuur is beschikbaar via `sensor.buitentempsensor_temperature`. De adviestemperatuur wordt al berekend in het Grafana dashboard als `clamp(buiten - 4, 22, 25)`, maar bestaat nog niet als HA-entiteit.

Templates worden in dit project via NixOS beheerd: `modules/hassio/templates/stookwijzer.yaml` wordt via `activationScript` naar `/var/lib/homeassistant/templates/` gekopieerd en via `homeassistant: packages` geladen. Hetzelfde patroon geldt hier.

## Goals / Non-Goals

**Goals:**
- Template sensor `sensor.airco_werkkamer_advies_temperatuur` beschikbaar in HA
- HA script dat airco instelt op cool-modus met de adviestemperatuur (één service call)
- Button card op het bestaande Airco dashboard

**Non-Goals:**
- Automatisch instellen bij airco aanzetten
- Integratie met andere kamers of airco's
- Persistentie van de adviestemperatuur buiten HA

## Decisions

**Template sensor via NixOS (niet via HA UI helpers)**
De formule en sensor-definitie horen in git. De stookwijzer-aanpak is het bestaande patroon in dit project: YAML-bestand in `modules/hassio/templates/`, gekopieerd via `activationScript`, geladen via HA `packages:` in `configuration.yaml`.

**`climate.set_temperature` met `hvac_mode: cool` in één call**
HA ondersteunt het meegeven van `hvac_mode` in `climate.set_temperature`. Dit is één service call in plaats van twee aparte (`set_hvac_mode` + `set_temperature`), wat atomischer is en eenvoudiger te lezen in het script.

**Script en button card via HA UI**
Scripts en dashboard-aanpassingen worden in dit project niet via NixOS beheerd (conform bestaande werkwijze). Ze worden via de HA UI aangemaakt en staan in `scripts.yaml` en de dashboard-configuratie — buiten git.

## Risks / Trade-offs

- [Template laadt niet] HA laadt templates via `packages:` in `configuration.yaml`. Als dit pad niet geconfigureerd is, verschijnt de sensor niet. → Controleer na deploy of `sensor.airco_werkkamer_advies_temperatuur` beschikbaar is in Developer Tools.
- [Buitensensor unavailable] Als `sensor.buitentempsensor_temperature` `unavailable` of `unknown` is, geeft `| float(20)` een fallback van 20°C → advies 22°C (ondergrens). Dit is een veilige fallback.
- [Script niet in git] Het HA script en de button zijn niet versiegebeheerd. Bij een HA reset of migratie moeten ze opnieuw aangemaakt worden. → Documenteer de script-inhoud in de tasks.

## Migration Plan

1. `nixos-rebuild switch` op malandro → kopieert `airco.yaml` naar `/var/lib/homeassistant/templates/`
2. HA herladen (Developer Tools → YAML → Alles herladen) of `homeassistant.reload_config_entry`
3. Controleer `sensor.airco_werkkamer_advies_temperatuur` in HA Developer Tools
4. Script aanmaken via HA UI (Instellingen → Scripts)
5. Button card toevoegen via HA dashboard editor
