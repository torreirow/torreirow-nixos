# Changelog

All notable changes to this NixOS configuration.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## NEXT VERSION

### Added
- **Hyprland font scaling**: X11/XWayland apps tonen nu dezelfde tekstgrootte als Wayland apps via `Xft.dpi = 120` (96 × monitor scale 1.25). Daarnaast zijn er drie keybindings voor runtime tekstgrootte-aanpassing via `gsettings text-scaling-factor` met visuele feedback:
  - `Super+Ctrl+Shift+=` — tekst groter (+0.1, max 2.0)
  - `Super+Ctrl+Shift+-` — tekst kleiner (-0.1, min 0.8)
  - `Super+Ctrl+Shift+0` — reset naar standaard (1.0)
- **Hyprland workspace-monitor binding**: Workspaces 1-10 zijn persistent en worden dynamisch aan de externe monitor gekoppeld. WS 1, 4, 6, 8, 10 landen op het externe scherm; WS 2, 3, 5, 7, 9 op de laptop. Werkt automatisch thuis én op kantoor ongeacht de poortnaam (HDMI-A-1, DP-10, etc.) via een `workspace-binder` service die monitor-events afluistert. Apps Slack/Teams → WS 3, Firefox → WS 4.
- **Wayle weather `location-name` override**: Voeg `location-name` config optie toe aan de wayle weather module via een lokale fork. Hiermee is het mogelijk coördinaten te gebruiken voor accurate weerdata terwijl een leesbare naam in de dropdown header wordt getoond (bijv. `location-name = "Ermelo"`). Oplossing voor het probleem dat coördinaten een lege/incorrecte naam gaven, en een stadsnaam de verkeerde stad opleverde (Open-Meteo geocoding geeft de Zuidafrikaanse Ermelo vóór de Nederlandse).
  - Nix overlay toegevoegd (`overlays/wayle.nix`) voor lokale wayle fork
  - `location-name` veld toegevoegd aan `WeatherConfig` schema in de fork
  - Weather dropdown header toont nu geconfigureerde naam i.p.v. API-resultaat

### Fixed
- **Wayle weather crash bij Refresh**: `trigger_refresh()` in de wayle fork gebruikte `LocationQuery::city()` ongeacht de locatie-invoer, waardoor coördinaten (`"52.2983,5.6222"`) werden doorgegeven aan de Open-Meteo geocoding API als plaatsnaam — resulterend in `location not found`. De fix past dezelfde coördinatendetectie toe (`split_once(',')` → `parse::<f64>()`) als de rest van de codebase.
- **SubtitleEdit Ctrl-X/Ctrl-V clipboard**: `autocutsel` toegevoegd aan Hyprland exec-once om de X11 clipboard actief te houden. SubtitleEdit draait via Mono/XWayland en verliest de clipboard selection zodra de muisknop wordt losgelaten; `autocutsel` synchroniseert de X11 PRIMARY selection naar de clipboard continu.
