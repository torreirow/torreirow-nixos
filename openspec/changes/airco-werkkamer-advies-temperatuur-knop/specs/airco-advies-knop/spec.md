## ADDED Requirements

### Requirement: Adviestemperatuur sensor beschikbaar in HA
HA SHALL een template sensor `sensor.airco_werkkamer_advies_temperatuur` bieden die de geadviseerde koeltemperatuur berekent als `clamp(buitentemperatuur − 4, 22°C, 25°C)`, gebaseerd op `sensor.buitentempsensor_temperature`.

#### Scenario: Normale buitentemperatuur
- **WHEN** `sensor.buitentempsensor_temperature` is 28°C
- **THEN** `sensor.airco_werkkamer_advies_temperatuur` geeft 24°C terug

#### Scenario: Hoge buitentemperatuur (bovengrens)
- **WHEN** `sensor.buitentempsensor_temperature` is 32°C of hoger
- **THEN** `sensor.airco_werkkamer_advies_temperatuur` geeft maximaal 25°C terug

#### Scenario: Lage buitentemperatuur (ondergrens)
- **WHEN** `sensor.buitentempsensor_temperature` is 24°C of lager
- **THEN** `sensor.airco_werkkamer_advies_temperatuur` geeft minimaal 22°C terug

#### Scenario: Buitensensor niet beschikbaar
- **WHEN** `sensor.buitentempsensor_temperature` is `unavailable` of `unknown`
- **THEN** `sensor.airco_werkkamer_advies_temperatuur` geeft 22°C terug (veilige fallback via float(20))

### Requirement: Airco instellen via HA script
HA SHALL een script bieden dat `climate.airco_werkkamer_zolder` instelt op `hvac_mode: cool` met als doeltemperatuur de huidige waarde van `sensor.airco_werkkamer_advies_temperatuur`.

#### Scenario: Script uitvoeren
- **WHEN** `script.airco_werkkamer_op_advies` wordt aangeroepen
- **THEN** wordt `climate.set_temperature` aangeroepen op `climate.airco_werkkamer_zolder` met `hvac_mode: cool` en `temperature` gelijk aan de huidige adviestemperatuur

### Requirement: Button card op Airco dashboard
Het Airco dashboard SHALL een button card bevatten waarmee de gebruiker met één klik het advies-script kan aanroepen.

#### Scenario: Klik op knop
- **WHEN** de gebruiker klikt op de "Stel in op advies" knop in het Airco dashboard
- **THEN** wordt `script.airco_werkkamer_op_advies` uitgevoerd en de airco ingesteld op cool met de adviestemperatuur
