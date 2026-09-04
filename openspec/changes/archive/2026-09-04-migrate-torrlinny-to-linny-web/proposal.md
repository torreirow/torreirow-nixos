## Why

`modules/torrlinny.nix` bevatte een volledige, malandro-specifieke kopie van de clone → `hugo mod
get` → `hugo` → atomic-swap → keep-last-good → timer-logica. Sinds epic `nixos-dhh8` bestaat die
logica als een herbruikbare module (`services.linny-web`, repo `linny-web-theme`). Deze change
migreert torrlinny naar die gedeelde module, zodat er nog maar één implementatie onderhouden wordt.
De **externe capability blijft identiek** (geauthenticeerde, doorzoekbare static site op
`linny.toorren.net` die automatisch herbouwt) — dit is een refactor, geen gedragsverandering.

## What Changes

- **`linny-web-theme` module uitgebreid** met optionele **SSH-deploy-key-auth** (`gitSshKeyFile`)
  naast de token-auth (`gitTokenFile`); precies één is vereist (assertion). Zo houdt torrlinny zijn
  bestaande read-only agenix deploy-key.
- **`flake.nix`** (torreirow-nixos): nieuwe input `linny-web` (`github:torreirow/linny-web-theme`),
  en `inputs.linny-web.nixosModules.linny-web` toegevoegd aan de malandro modules-lijst.
- **`modules/torrlinny.nix`** herschreven tot een **dunne wrapper**: behoudt
  `options.services.torrlinny.{enable,domain,acmeHost}`; de config zet de agenix deploy-key,
  `services.linny-web` (met `gitSshKeyFile`, `user = torrlinny`, `stateDir = /var/lib/torrlinny`,
  `webRoot = …/live`, `baseURL`), voegt de `keys`-groep toe aan `linny-web-build`, en definieert de
  bestaande **Authelia-vhost** zelf (niet de dunne nginx-helper van de module).
- Systemd-unit heet nu **`linny-web-build.service`/`.timer`** (was `torrlinny-build`). Werkmap
  ongewijzigd (`/var/lib/torrlinny`) zodat de live-build ononderbroken doorloopt.
- `docs/torrlinny.md` bijgewerkt.

## Capabilities

### New Capabilities
<!-- Geen. -->

### Modified Capabilities
<!-- Geen requirement-wijzigingen: torrlinny-web gedraagt zich extern identiek. Puur een
     implementatie-refactor (build draait nu via de gedeelde services.linny-web module). -->

## Impact

- **Gewijzigd:** `modules/torrlinny.nix` (wrapper), `flake.nix` + `flake.lock` (input + malandro
  modules-lijst), `docs/torrlinny.md`. In `linny-web-theme`: `nix/linny-web.nix`, `flake.nix`,
  README, CHANGELOG (SSH-auth, commit `506ba2e`).
- **Ongewijzigd:** de deploy-key (`secrets/torrlinny-deploy-key.age`), de Authelia-vhost, de URL,
  de werkmap `/var/lib/torrlinny`.
- **Geverifieerd op malandro:** `dry-build` schoon, `switch` schoon, `linny-web-build` bouwt (rev
  6c5906f gepubliceerd via SSH-deploy-key), live-symlink ok, checkout `0700` (privé), site geeft
  `302 → auth.toorren.net` (Authelia), oude `torrlinny-build`-units verdwenen.
- **Buiten scope:** de GitHub-webhook-trigger (`nixos-bvhd`, draft).
