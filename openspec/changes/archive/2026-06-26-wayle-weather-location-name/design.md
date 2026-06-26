## Context

Wayle haalt weerdata op via de `wayle-weather` crate (in de `wayle-services` repo). Wanneer `location` een komma-gescheiden getal is (bijv. `"52.29,5.62"`) wordt het als coördinaten geparsed en slaat de geocoding stap over — de `Location` struct krijgt lege `city` en `country` velden. De dropdown header toont dan `location_display("", None, "")` → `","`.

Alternatief: een stadsnaam gebruiken triggert forward geocoding via Open-Meteo, maar voor "Ermelo" returnt de API Zuidafrika als eerste resultaat.

De `LocationQuery::city_country(name, country)` methode bestaat al in `wayle-weather` en stuurt een `countryCode` query parameter mee — de infrastructuur is compleet. De `parse_location` functie in `bootstrap/weather.rs` gebruikt hem echter nooit.

**Twee repos betrokken:**
- `wayle` fork (Rust): config schema + bootstrap
- `torreirow-nixos` (Nix): overlay + wayle config

## Goals / Non-Goals

**Goals:**
- `location-country` config veld toevoegen aan wayle weather module
- Bij `location = "Ermelo"` + `location-country = "NL"` geeft de dropdown "Ermelo, Gelderland"
- Geen wijzigingen aan `wayle-services` nodig
- Nix overlay zodat de fork gebouwd wordt vanuit de lokale repo

**Non-Goals:**
- Reverse geocoding bij gebruik van coördinaten (apart probleem)
- Upstream PR naar `wayle-rs/wayle` (kan later)
- Wijzigingen aan andere weather providers (VisualCrossing, WeatherAPI)

## Decisions

### 1. Veld naam: `location-country` (niet `country-code`)

`location-country` sluit aan bij de bestaande `location` veld naamgeving in wayle. Alternatieven zoals `country-code` of `geocoding-country` zijn technischer en minder gebruiksvriendelijk.

### 2. `Option<String>` type — veld is optioneel

Bestaand gedrag ongewijzigd bij weglaten van `location-country`. Geen breaking change, geen migratie nodig voor bestaande configs.

### 3. Nix overlay via `overrideAttrs` met lokaal pad

De fork staat lokaal op `/home/wtoorren/data/git/torreirow/way`. Overlay gebruikt `src = /home/wtoorren/data/git/torreirow/way` zodat lokale wijzigingen direct opgepikt worden zonder GitHub push. `cargoHash` wordt op `lib:fake` gezet tijdens development, daarna bijgewerkt.

### 4. Aanpassing in `build_weather_service`, niet in `parse_location`

`parse_location` is een pure functie die alleen de `location` string kent. Country toevoegen vereist een tweede parameter of refactor. Eenvoudiger: lees beide velden in `build_weather_service` en kies de juiste `LocationQuery` variant daar.

## Risks / Trade-offs

- **cargoHash synchronisatie** → Bij elke wijziging in de fork moet `cargoHash` in de overlay bijgewerkt worden. Nix geeft een duidelijke foutmelding met de correcte hash.
- **Lokaal pad in flake** → `src = /home/wtoorren/data/git/torreirow/way` werkt alleen op deze machine. Acceptabel voor een persoonlijke NixOS config.
- **Upstream divergentie** → Als wayle upstream een nieuwe versie uitbrengt moet de overlay bijgewerkt worden. Bijhouden via `version` in de overlay.
