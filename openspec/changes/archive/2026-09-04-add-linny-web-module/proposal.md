## Why

De `linny-web-theme` Hugo-module maakt een Linny-notebook doorzoekbaar in de browser, maar het
*serveren* ervan zit nu vastgeklonken in de malandro-specifieke `modules/torrlinny.nix`: een
hardcoded repo (`torreirow/torrlinny`), een agenix deploy-key en een ingebakken Authelia/nginx-vhost.
Andere Linny-gebruikers kunnen die module niet hergebruiken. Er is behoefte aan een **herbruikbare
NixOS-module** waarmee elke Linny-gebruiker haar privé linny-notes-repo met **minimale one-time-config**
als statische site kan publiceren — webserver-agnostisch, zonder agenix/Authelia als harde eis.

## What Changes

- Nieuwe **flake** in de aparte repo `github.com/torreirow/linny-web-theme` die
  `nixosModules.linny-web` (en `nixosModules.default`) exporteert. Plain nix voor de architecturen
  (x86_64-linux, aarch64-linux), geen `flake-utils`.
- Nieuwe **NixOS-module** `nix/linny-web.nix` (in die repo), gegeneraliseerd uit `torrlinny.nix`:
  - Verplichte one-time-config = **3 velden**: `gitRepo`, `gitTokenFile`, `baseURL`.
  - Optioneel: `webRoot`, `stateDir`, `user`, `interval`, `themeModule`, `configFile`.
  - **Static build** (geen `hugo server`): `hugo mod get` → `hugo build` → **atomic symlink-swap** →
    `webRoot`, met **keep-last-good** bij een build-fout en prune van oude builds.
  - **Auth via fine-grained PAT**: HTTPS-clone met `git -c http.<host>.extraheader` uit
    `gitTokenFile` (token niet in URL/proceslijst).
  - **Permissie-model**: privé checkout (`0700`, notities blijven privé) + wereld-leesbare
    build-output (`chmod a+rX`) zodat elke webserver (nginx/apache/caddy) `webRoot` kan lezen zonder
    groep-koppeling.
  - **Timer** met change-detectie (git `HEAD` + bouw-recept `hugo=<v>;go=<v>`).
  - Optionele **dunne nginx-helper** (`services.linny-web.nginx = { enable; virtualHost; useACMEHost; }`).
- **Docs** in de theme-repo: README-sectie "Serve it on NixOS" + CHANGELOG-entry.

## Capabilities

### New Capabilities
- `linny-web-module`: Een herbruikbare NixOS-module die een privé Linny-notebook-repo cloont, met de
  `linny-web-theme` bouwt en als robuuste (atomic + keep-last-good) statische site publiceert, met
  minimale one-time-config en zonder afhankelijkheid van een specifieke webserver of secrets-stack.

### Modified Capabilities
<!-- Geen bestaande capability-requirements wijzigen. torrlinny blijft ongemoeid. -->

## Impact

- **Nieuw (in repo `linny-web-theme`):** `flake.nix`, `flake.lock`, `nix/linny-web.nix`,
  README-sectie, CHANGELOG-entry.
- **Nieuw (in deze repo):** deze OpenSpec-change + child-beans onder epic `nixos-dhh8`.
- **Ongewijzigd:** `modules/torrlinny.nix` blijft zoals het is (migratie is een aparte, latere bean).
- **Afhankelijkheden module:** `pkgs.hugo` (extended), `pkgs.go`, `git`, `openssh`. Geen draaiend
  service-proces (statische output). Geen extra firewall-poort.
- **Buiten scope:** torrlinny migreren naar deze module; GitHub-webhook-trigger (blijft `nixos-bvhd`).
