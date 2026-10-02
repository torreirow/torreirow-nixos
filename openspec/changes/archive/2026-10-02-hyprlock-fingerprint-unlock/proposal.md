# Proposal

## Why

Het lockscreen van lobos (hyprlock) is alleen met een wachtwoord te ontgrendelen, terwijl de
Synaptics-vingerafdruksensor werkt en er vier vingers geregistreerd zijn. Vingerafdruk werd eerder
bewust uitgezet via PAM (`fprintAuth = false`), omdat `pam_fprintd` sequentieel in de PAM-stack
blokkeert: tot de vinger of de timeout (~30s) kwam het wachtwoord niet aan de beurt. hyprlock
v0.9.5 heeft een eigen fingerprint-pad via D-Bus dat **parallel** aan PAM loopt. Daarmee komt
vingerafdruk terug zonder die wachttijd.

## What Changes

- hyprlock krijgt native fingerprint-ontgrendeling (D-Bus → fprintd), naast het bestaande
  wachtwoord via PAM. Wat het eerst slaagt, ontgrendelt.
- Stil: geen prompt-label of statustekst voor de vingerafdruk op het lockscreen.
- De PAM-service `hyprlock` houdt `fprintAuth = false`. Alleen het commentaar wordt aangepast,
  zodat het niet langer suggereert dat vingerafdruk helemaal uit staat.
- Ontgrendelen na een suspend/resume wordt expliciet getest. Een resume-hook wordt alleen
  toegevoegd als die test faalt.
- Buiten scope: sudo, greetd en andere PAM-services.

## Capabilities

### New Capabilities
- `lockscreen-unlock`: hoe het lockscreen van lobos ontgrendeld kan worden (wachtwoord en
  vingerafdruk, parallel, zonder blokkade), ook na een suspend/resume.

### Modified Capabilities
<!-- geen -->

## Impact

- `home/hyprland/hyprlock.nix`: `auth`-sectie (home-manager, `wtoorren@linuxdesktop`).
- `hosts/lobos/hyprland.nix`: alleen het commentaar bij `security.pam.services.hyprlock`.
  Gedrag en closure veranderen niet.
- Eventueel (alleen als de resume-test faalt): een resume-unit in `hosts/lobos/power-management.nix`.
- Runtime-afhankelijkheid: `services.fprintd` (staat al aan) en de geregistreerde vingers van
  `wtoorren`.
