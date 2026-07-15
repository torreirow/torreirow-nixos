## Why

De tmux statusbar toont momenteel alleen `🔓 unlocked` of `🔒 locked`, zonder aanduiding welk rbw-profiel actief is. Bij gebruik van meerdere profielen (persoonlijk vs. werk) is niet direct zichtbaar in welke context je werkt.

## What Changes

- De rbw-indicator in `status-right` verandert van `🔓 unlocked` / `🔒 locked` naar `🔓 bw <label>` / `🔒 bw <label>`
- Bovenaan `home/tmux.nix` wordt een Nix-mapping `rbwProfiles` gedefinieerd die `RBW_PROFILE`-waarden vertaalt naar korte labels
- Nix genereert automatisch een shell `case`-statement vanuit deze mapping
- De foutieve inline if-structuur in `status-right` wordt vervangen door een `pkgs.writeShellScript`

## Capabilities

### New Capabilities

- `rbw-status-label`: Shell script dat op basis van `$RBW_PROFILE` een kort label bepaalt en combineert met de rbw lock-status voor weergave in de tmux statusbar

### Modified Capabilities

## Impact

- `home/tmux.nix`: mapping-definitie, gegenereerd shell script, aanpassing `status-right`
- Geen externe afhankelijkheden; `rbw` was al aanwezig
