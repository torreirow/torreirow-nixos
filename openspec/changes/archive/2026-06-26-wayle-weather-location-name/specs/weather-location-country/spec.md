## ADDED Requirements

### Requirement: location-country config veld
De weather module SHALL een optioneel `location-country` veld ondersteunen. Wanneer aanwezig én `location` een stadsnaam is (geen coördinaten), SHALL de geocoding API call een `countryCode` parameter meesturen met de opgegeven waarde.

#### Scenario: Stadsnaam met country code
- **WHEN** `location = "Ermelo"` en `location-country = "NL"` geconfigureerd zijn
- **THEN** stuurt wayle `countryCode=NL` mee naar de Open-Meteo geocoding API en returnt de Nederlandse Ermelo

#### Scenario: Veld weggelaten
- **WHEN** `location-country` niet aanwezig is in de config
- **THEN** gedraagt de weather module zich identiek aan het huidige gedrag (geen `countryCode` parameter)

#### Scenario: Coördinaten met country code
- **WHEN** `location = "52.29,5.62"` (coördinaten) én `location-country = "NL"` geconfigureerd zijn
- **THEN** wordt `location-country` genegeerd — coördinaten slaan geocoding over

### Requirement: Dropdown toont correcte locatienaam
Wanneer `location-country` gebruikt wordt en geocoding succesvol is, SHALL de weather dropdown header de teruggegeven stadsnaam en regio tonen in plaats van een lege string of komma.

#### Scenario: Correcte naam in dropdown header
- **WHEN** `location = "Ermelo"` en `location-country = "NL"` en de geocoding API returnt stad "Ermelo" met regio "Gelderland"
- **THEN** toont de dropdown header "Ermelo, Gelderland"
