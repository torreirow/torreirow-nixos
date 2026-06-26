## Why

Bij gebruik van GPS-coördinaten als `location` in de wayle weather module retourneert de Open-Meteo API geen locatienaam — de dropdown header toont dan ", NL" of enkel een komma. Alternatief een stadsnaam gebruiken werkt niet voor Ermelo omdat Open-Meteo dan de Zuidafrikaanse Ermelo als eerste resultaat teruggeeft.

## What Changes

- Nieuw optioneel config veld `location-country` toevoegen aan de wayle weather module (geforkte repo `/home/wtoorren/data/git/torreirow/way`)
- `build_weather_service()` aanpassen om bij aanwezigheid van `location-country` de `LocationQuery::city_country()` methode te gebruiken in plaats van `LocationQuery::city()`
- Nix overlay toevoegen aan `flake.nix` die de nixpkgs wayle package overschrijft met de lokale fork
- `wayle.nix` updaten: coördinaten vervangen door `location = "Ermelo"` + `location-country = "NL"`

## Capabilities

### New Capabilities

- `weather-location-country`: Optioneel `location-country` config veld voor de weather module dat de Open-Meteo geocoding API filtert op landcode, zodat steden in het juiste land worden gevonden.

### Modified Capabilities

<!-- geen bestaande specs -->

## Impact

- **wayle fork** (`/home/wtoorren/data/git/torreirow/way`): 2 Rust bestanden gewijzigd
  - `crates/wayle-config/src/schemas/modules/weather/mod.rs`
  - `crates/wayle-shell/src/bootstrap/weather.rs`
- **torreirow-nixos**: `flake.nix` (overlay) en `home/hyprland/wayle.nix` (config)
- **Geen breaking changes**: veld is optioneel, bestaand gedrag ongewijzigd
- **Afhankelijkheid**: `LocationQuery::city_country()` bestaat al in `wayle-weather` crate — geen wijzigingen in `wayle-services` nodig
