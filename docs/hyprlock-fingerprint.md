# Hyprlock vingerafdruk-unlock (lobos)

Vingerafdruk ontgrendelen op het hyprlock-lockscreen, de claim-retry-patch en roterende lock-teksten.

> Verplaatst uit CLAUDE.md (Huidige Status) om de sessie-context slank te houden.

### Sessie 2026-10-02 - Vingerafdruk op het lockscreen (hyprlock, lobos) - LIVE EN GETEST

**Doel:** hyprlock ontgrendelen met vingerafdruk. OpenSpec change `hyprlock-fingerprint-unlock`.
Sensor: Synaptics, 4 vingers geregistreerd (`fprintd-list wtoorren`).

**Waarom het uit stond:** `security.pam.services.hyprlock.fprintAuth = false` (`hosts/lobos/hyprland.nix`).
`pam_fprintd` werkt **sequentieel**: het blokkeert tot vinger of timeout (~30s) vóór `pam_unix` het
wachtwoord ziet. **Die regel blijft `false`.** Vingerafdruk loopt nu via hyprlock's eigen D-Bus-pad
(`auth { fingerprint:enabled = true }` in `home/hyprland/hyprlock.nix`), **parallel** aan PAM. Zet
`fprintAuth` niet "voor de zekerheid" weer aan: dan strijden twee clients om de sensor en komt de
blokkade terug. Icoon 󰈷 (U+F0237) als los label **onder** het invoerveld (`position "0, -110"`), niet in het tekstvak; géén `$FPRINTPROMPT`-statustekst.

**Roterende lock-teksten:** pools bovenin `home/hyprland/hyprlock.nix`. `hyprlock-rotate-texts` schrijft
`~/.local/state/hyprlock/texts.conf` (`$LOCK_PLACEHOLDER`/`$LOCK_FAIL`), aangeroepen door de HM-activatie en
hypridle `on_unlock_cmd` (Hyprland lock-notificatie, dus alle lock-routes). `source` staat in
`importantPrefixes`, anders komt het ná `input-field` en zijn de variabelen nog leeg. Geen `#` in teksten
(hyprlang-commentaar). `$USER`/`$ATTEMPTS` vult hyprlock zelf in. SC2016 bewust uitgezet in het script.

**Bug in hyprlock 0.9.5 (gepatcht):** `claimDevice()` probeert het **één keer**. Faalt de Claim, dan is
fingerprint dood voor die hele lock-sessie (wachtwoord werkt wel, dus het lijkt alsof "de sensor niks
doet"). Twee triggers, beide uit de journal gehaald:
- **Snel opnieuw vergrendelen na een wachtwoord-unlock.** De Synaptics-close na een afgebroken verify
  kan ~70s duren (`Error closing device after disconnect: transfer timed out`). Een nieuwe hyprlock
  binnen dat venster krijgt `Claim: Device was already claimed`.
- **Vergrendelen + suspend.** fprintd stopt na 30s ongebruikt. Die timer loopt in s2idle stil en vuurde
  precies bij de resume, terwijl hyprlock opnieuw claimde.

**Fix:** overlay `overlays/hyprlock.nix` + `overlays/patches/hyprlock-fprint-reclaim.patch` (na wake
release + proxy weg + opnieuw claimen, port van upstream **PR #1049**; Claim-retry met backoff 0,5s→30s,
12 pogingen). De overlay staat in de lobos-NixOS- **én** de HM-overlays in `flake.nix` (hyprlock staat
in allebei op PATH, nu hetzelfde store-path). fprintd draait met **`--no-timeout`**
(`hosts/lobos/configuration.nix`).

**Let op bij nixpkgs-bumps:** past de patch niet meer, dan krijg je een buildfout (niet stil falen).
**Niet blind naar hyprlock 0.9.6:** issue **#1074** meldt dat snel opnieuw vergrendelen daar juist slechter
werkt. Haal de patch weg zodra upstream PR #1049 (of gelijkwaardig) gemerged is.

**Getest:** vinger, wachtwoord direct (geen wachttijd), foute vinger → wachtwoord, stil scherm, snel opnieuw
vergrendelen na een wachtwoord-unlock, en vergrendelen + suspend >5 min → vinger. Allemaal OK. fprintd
bleef met `--no-timeout` door de suspend heen draaien. Niet aangetoond: dat het claim-retry-pad echt
gelopen heeft (hyprlock logt niet naar de journal, en de close-hang trad bij de hertest niet op).

**Status:** ✅ Live en getest.
