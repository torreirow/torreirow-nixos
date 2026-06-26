# Changelog

All notable changes to this NixOS configuration.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## NEXT VERSION

### Added
- **Wayle weather `location-name` override**: Voeg `location-name` config optie toe aan de wayle weather module via een lokale fork. Hiermee is het mogelijk coördinaten te gebruiken voor accurate weerdata terwijl een leesbare naam in de dropdown header wordt getoond (bijv. `location-name = "Ermelo"`). Oplossing voor het probleem dat coördinaten een lege/incorrecte naam gaven, en een stadsnaam de verkeerde stad opleverde (Open-Meteo geocoding geeft de Zuidafrikaanse Ermelo vóór de Nederlandse).
  - Nix overlay toegevoegd (`overlays/wayle.nix`) voor lokale wayle fork
  - `location-name` veld toegevoegd aan `WeatherConfig` schema in de fork
  - Weather dropdown header toont nu geconfigureerde naam i.p.v. API-resultaat

### Fixed
- **SubtitleEdit Ctrl-X/Ctrl-V clipboard**: `autocutsel` toegevoegd aan Hyprland exec-once om de X11 clipboard actief te houden. SubtitleEdit draait via Mono/XWayland en verliest de clipboard selection zodra de muisknop wordt losgelaten; `autocutsel` synchroniseert de X11 PRIMARY selection naar de clipboard continu.
