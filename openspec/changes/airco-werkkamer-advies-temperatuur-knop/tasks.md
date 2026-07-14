## 1. NixOS: Template sensor aanmaken

- [x] 1.1 Maak `modules/hassio/templates/airco.yaml` aan met template sensor `sensor.airco_werkkamer_advies_temperatuur` (formule: `clamp(buiten - 4, 22, 25)`, bron: `sensor.buitentempsensor_temperature`, fallback `| float(20)`)
- [x] 1.2 Voeg deploy van `airco.yaml` toe aan de `activationScript` in `modules/hassio/default.nix` (kopieer naar `/var/lib/homeassistant/templates/airco.yaml`)
- [ ] 1.3 Voer `sudo nixos-rebuild switch --flake .#malandro` uit op malandro
- [ ] 1.4 Controleer of `/var/lib/homeassistant/templates/airco.yaml` aanwezig is op malandro

## 2. Home Assistant: Template laden en verifiëren

- [ ] 2.1 Herlaad HA configuratie (Developer Tools → YAML → Alles herladen, of herstart container)
- [ ] 2.2 Controleer in Developer Tools → Staten dat `sensor.airco_werkkamer_advies_temperatuur` bestaat en een geldige waarde toont (bijv. 22–25°C)

## 3. Home Assistant: Script aanmaken via HA UI

- [ ] 3.1 Ga naar Instellingen → Scripts → Script toevoegen in HA UI
- [ ] 3.2 Maak script aan met alias "Airco werkkamer op adviestemperatuur" en de volgende actie:
  ```yaml
  service: climate.set_temperature
  target:
    entity_id: climate.airco_werkkamer_zolder
  data:
    hvac_mode: cool
    temperature: "{{ states('sensor.airco_werkkamer_advies_temperatuur') | float }}"
  ```
- [ ] 3.3 Sla het script op en test het via de "Uitvoeren" knop — controleer of de airco overschakelt naar cool-modus met de juiste temperatuur

## 4. Home Assistant: Button card toevoegen aan Airco dashboard

- [ ] 4.1 Open het "Airco" dashboard in HA en ga naar bewerkingsmodus
- [ ] 4.2 Voeg een button card toe met de volgende configuratie:
  ```yaml
  type: button
  name: Stel in op advies
  icon: mdi:thermometer-auto
  tap_action:
    action: call-service
    service: script.airco_werkkamer_op_advies
  show_state: false
  ```
- [ ] 4.3 Sla het dashboard op en test de knop
