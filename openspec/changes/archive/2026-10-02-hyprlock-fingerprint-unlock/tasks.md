# Tasks

## 1. Configuratie

- [x] 1.1 Voeg in `home/hyprland/hyprlock.nix` een `auth`-sectie toe met `"pam:enabled" = true` en `"fingerprint:enabled" = true`, zonder label of meldingen; verifieer met `nix build .#homeConfigurations."wtoorren@linuxdesktop".activationPackage` en controleer dat de gegenereerde `hyprlock.conf` een `auth { ... fingerprint:enabled = true }`-blok bevat en geen `$FPRINTPROMPT`
- [x] 1.2 Pas het commentaar bij `security.pam.services.hyprlock` in `hosts/lobos/hyprland.nix` aan (fingerprint loopt via hyprlock's D-Bus-pad, PAM bewust zonder fprintd om blokkade te voorkomen); verifieer dat `fprintAuth = false` ongewijzigd is en `nix eval .#nixosConfigurations.lobos.config.security.pam.services.hyprlock.fprintAuth` `false` geeft
- [x] 1.3 User draait `home-manager switch`; verifieer dat `~/.config/hypr/hyprlock.conf` de `auth`-sectie bevat

## 2. Functionele test (vergrendeld, zonder suspend)

- [x] 2.1 Vergrendel met SUPER+L, leg een geregistreerde vinger; verifieer dat het scherm ontgrendelt
- [x] 2.2 Vergrendel, typ meteen het wachtwoord + Enter zonder vinger; verifieer dat het direct ontgrendelt (geen merkbare wachttijd)
- [x] 2.3 Vergrendel, leg een niet-geregistreerde vinger, daarna het wachtwoord; verifieer dat het scherm vergrendeld blijft na de foute vinger en het wachtwoord daarna ontgrendelt
- [x] 2.4 Vergrendel, wacht >60s (voorbij de idle-exit van fprintd), leg een vinger; verifieer dat het ontgrendelt
- [x] 2.5 Verifieer visueel dat het lockscreen alleen achtergrond, klok en invoerveld toont (geen fingerprint-tekst)

## 3. Suspend/resume-test

- [x] 3.1 Vergrendel + suspend met SUPER+SHIFT+L, hervat, leg een vinger; verifieer dat het ontgrendelt, en leg `journalctl -b -u fprintd --since "-10min"` vast
- [x] 3.2 Herhaal 3.1 met een langere suspend (>5 min); verifieer opnieuw ontgrendelen met vinger
- [x] 3.3 Alleen als 3.1/3.2 faalt: bepaal de oorzaak uit de fprintd-journal, voeg een fix toe als extra taak (bijv. resume-hook in `hosts/lobos/power-management.nix`) en herhaal 3.1; anders deze taak afvinken als "niet nodig" — oorzaak: hyprlock 0.9.5 claimt de sensor één keer zonder retry (design decision 5)
- [x] 3.4 Schrijf `overlays/patches/hyprlock-fprint-reclaim.patch` (bij wake opnieuw claimen + claim-retry met backoff) en `overlays/hyprlock.nix`; verifieer dat `nix build` van de gepatchte hyprlock slaagt en `hyprlock --version` 0.9.5 geeft
- [x] 3.5 Hang de overlay in de lobos-NixOS- en HM-overlays (flake.nix) en zet fprintd op `--no-timeout` (hosts/lobos); verifieer dat beide `hyprlock`-paden op PATH naar dezelfde gepatchte store-path wijzen en dat `systemctl cat fprintd` `--no-timeout` toont
- [x] 3.6 User/Claude draait `nixos-rebuild switch` + `home-manager switch`; herhaal 2.4 (snel opnieuw vergrendelen na een wachtwoord-unlock) en 3.2 (suspend >5 min); verifieer dat de vinger in beide gevallen ontgrendelt

## 4. Afronding

- [x] 4.1 Werk CLAUDE.md bij (sessie-entry: native hyprlock-fingerprint, waarom PAM-fprintd uit blijft, resultaat van de resume-test); verifieer dat de entry de resume-uitkomst vermeldt

## 5. Vingerafdruk-icoon (scope-wijziging na de tests)

- [x] 5.1 (later teruggedraaid, zie 5.4) Zet 󰈷 (U+F0237) als los label rechts in het invoerveld (`position = "260, 0"`, `zindex = 1`, `JetBrainsMono Nerd Font`) en maak placeholder/fail_text speelser (na twee eerdere iteraties op verzoek); verifieer dat de gegenereerde `hyprlock.conf` het label met `zindex=1` en de nieuwe teksten bevat, en nog steeds geen `$FPRINTPROMPT`
- [x] 5.2 (vervallen door 5.4) Visuele check van het icoon en dat ontgrendelen met de vinger nog werkt
- [x] 5.3 Werk CHANGELOG en de CLAUDE.md-sessie-entry bij ("stil" → "statisch icoon"); verifieer dat beide het icoon noemen

- [x] 5.4 Haal het icoon uit het tekstvak op verzoek van de user; verifieer dat `hyprlock.conf` geen 󰈷 meer in of over het invoerveld heeft
- [x] 5.5 Zet het icoon terug onder het invoerveld (`position = "0, -110"`, 48pt); verifieer dat `hyprlock.conf` het label bevat, en visueel (user) dat het onder het veld staat

## 6. Roterende lock-teksten (scope-wijziging)

- [x] 6.1 Voeg in `home/hyprland/hyprlock.nix` tekstpools (DevOps/Nix, professioneel), het script `hyprlock-rotate-texts`, `source` + `importantPrefixes`, `$LOCK_PLACEHOLDER`/`$LOCK_FAIL`, een HM-activatiestap en hypridle `on_unlock_cmd` toe; verifieer dat `hyprlock.conf` met `source=` begint, vóór `input-field`
- [x] 6.2 Draai `home-manager switch`; verifieer dat `~/.local/state/hyprlock/texts.conf` bestaat, dat twee handmatige runs van het script (meestal) verschillende teksten geven en dat `hypridle` het `on_unlock_cmd` kent
- [x] 6.3 User vergrendelt 2-3 keer; verifieer dat de placeholder per lock wisselt, dat een fout wachtwoord een fail-tekst uit de pool toont en dat vinger/wachtwoord blijven werken
- [x] 6.4 Werk CHANGELOG + CLAUDE.md bij (roterende teksten, mechaniek, waar de pools staan); verifieer dat beide het pad van de pools noemen
