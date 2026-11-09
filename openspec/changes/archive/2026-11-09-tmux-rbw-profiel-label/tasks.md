## 1. Nix mapping en script

- [x] 1.1 Voeg `rbwProfiles` attrset en `rbwDefaultLabel` toe bovenaan de `let`-block in `home/tmux.nix`
- [x] 1.2 Genereer de `case`-body via `lib.concatStringsSep` en `lib.mapAttrsToList` vanuit `rbwProfiles`
- [x] 1.3 Definieer `rbwStatus` als `pkgs.writeShellScript "rbw-status"` met de gegenereerde case-statement en rbw lock-check

## 2. Statusbar aanpassen

- [x] 2.1 Vervang de foutieve inline if-structuur in `status-right` door `#(${rbwStatus})`
- [x] 2.2 Verifieer dat de `lib`-import beschikbaar is in `home/tmux.nix` (voeg toe aan functie-argumenten indien nodig)

## 3. Testen

- [x] 3.1 Bouw de home-manager configuratie (`home-manager build`) en controleer op Nix-fouten
- [x] 3.2 Activeer met `home-manager switch` en controleer de statusbar zonder `RBW_PROFILE` gezet (2026-11-09: `🔓WT`; het formaat is later ingekort tot `<icon><label>`, spec bijgewerkt)
- [x] 3.3 Profiel `technative` geeft `TN` (2026-11-09: `🔒TN`). Een `export` in de shell bereikt de tmux-server niet; het script leest daarom ook `~/.config/rbw/active-profile` (gezet door `rbwsel`)
