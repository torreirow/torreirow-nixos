## 1. Wayle fork — config schema

- [x] 1.1 Voeg `location_name: ConfigProperty<Option<String>>` toe aan `WeatherConfig` in `crates/wayle-config/src/schemas/modules/weather/mod.rs`
- [x] 1.2 Voeg FTL i18n entry toe aan `crates/wayle-i18n/locales/en-US/config/modules/_weather.ftl`
- [x] 1.3 Voeg FTL i18n entry toe aan `crates/wayle-i18n/locales/fr/config/modules/_weather.ftl`

## 2. Wayle fork — weather header display

- [x] 2.1 Gebruik `location_name` config als override voor de locatienaam in de dropdown header (`crates/wayle-shell/src/shell/bar/dropdowns/weather/weather_header/methods.rs`)

## 3. Nix overlay

- [x] 3.1 Maak `overlays/wayle.nix` aan met `overrideAttrs` die lokale fork gebruikt
- [x] 3.2 Voeg overlay toe aan `wtoorren@linuxdesktop` in `flake.nix`

## 4. NixOS config updaten

- [x] 4.1 Laat `location = "52.2983,5.6222"` staan (coördinaten voor correcte weerdata)
- [x] 4.2 Voeg `location-name = "Ermelo"` toe in `home/hyprland/wayle.nix`

## 5. Bouwen en testen

- [x] 5.1 Bouw via home-manager switch
- [x] 5.2 Verifieer dat de dropdown header "Ermelo" toont i.p.v. een komma of Zuidafrikaanse stad
