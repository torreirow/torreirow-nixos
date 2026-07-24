## 1. Nix mapping en script

- [x] 1.1 Voeg `rbwProfiles` attrset en `rbwDefaultLabel` toe bovenaan de `let`-block in `home/tmux.nix`
- [x] 1.2 Genereer de `case`-body via `lib.concatStringsSep` en `lib.mapAttrsToList` vanuit `rbwProfiles`
- [x] 1.3 Definieer `rbwStatus` als `pkgs.writeShellScript "rbw-status"` met de gegenereerde case-statement en rbw lock-check

## 2. Statusbar aanpassen

- [x] 2.1 Vervang de foutieve inline if-structuur in `status-right` door `#(${rbwStatus})`
- [x] 2.2 Verifieer dat de `lib`-import beschikbaar is in `home/tmux.nix` (voeg toe aan functie-argumenten indien nodig)

## 3. Testen

- [x] 3.1 Bouw de home-manager configuratie (`home-manager build`) en controleer op Nix-fouten
- [ ] 3.2 Activeer met `home-manager switch` en controleer de statusbar zonder `RBW_PROFILE` gezet (verwacht: `🔒 bw WT` of `🔓 bw WT`)
- [ ] 3.3 Stel `export RBW_PROFILE=technative` in en wacht op statusbar-refresh (verwacht: `🔓 bw TN` of `🔒 bw TN`)
