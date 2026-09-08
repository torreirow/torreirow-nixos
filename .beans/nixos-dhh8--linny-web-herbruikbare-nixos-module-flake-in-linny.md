---
# nixos-dhh8
title: 'linny-web: herbruikbare NixOS-module (flake in linny-web-theme, minimale one-time-config)'
status: completed
type: epic
priority: normal
created_at: 2026-09-04T08:25:03Z
updated_at: 2026-09-04T11:38:30Z
---

De `linny-web-theme` Hugo-module verpakken als een **herbruikbare NixOS-module**, zodat
elke Linny-gebruiker haar privé linny-notes-repo met **minimale one-time-config** als een
doorzoekbare statische site kan serveren. Generalisatie van de bestaande, malandro-specifieke
`modules/torrlinny.nix`.

## Doel
Andere Linny-gebruikers kunnen met **3 verplichte velden** (`gitRepo`, `gitTokenFile`,
`baseURL`) een privé linny-notes-repo laten clonen, bouwen (Hugo + `linny-web-theme`) en als
static site publiceren — webserver-agnostisch. Geen agenix/Authelia/nginx als harde eis.

## Distributie
- **Flake in de `linny-web-theme`-repo** die `nixosModules.linny-web` exporteert (theme +
  NixOS-module reizen samen; andere gebruikers doen één flake input + import).

## Ontwerp-besluiten (uit deze sessie)
- **Static build, GEEN `hugo server`.** hugo-server is een dev-server (watcht fs, geen
  git-remote, geen TLS/auth, geen keep-last-good) → niet geschikt voor serveren. We houden het
  torrlinny-patroon: `hugo` build → `builds/<rev>-<ts>` → **atomic symlink-swap** naar `live`,
  met **keep-last-good** bij bouwfout.
- **Auth naar de repo = HTTPS-clone met fine-grained PAT** (i.p.v. SSH deploy-key). Token via
  `gitTokenFile`-pad (gebruiker regelt agenix/sops/plain zelf). Clone/fetch met
  `git -c http.<host>.extraheader="Authorization: Bearer $(cat $TOKEN)"` → token niet in de
  proceslijst/URL. Fine-grained token met **Contents: read-only** op die ene repo is genoeg.
- **`webRoot` als optie**: de live-map (default `${stateDir}/live`), **wereld-leesbaar**
  (`chmod a+rX`) zodat elke webserver (nginx/apache/caddy) 'm kan lezen zonder groep-koppeling.
  Module **publiceert** dit pad; de gebruiker legt de één-regel-koppeling
  (`services.nginx.virtualHosts.X.root = config.services.linny-web.webRoot`).
- **`baseURL` verplicht veld** (geen zinnige default; bepaalt canonieke links/sitemap/RSS/assets).
- **Optionele dunne nginx-helper (B)**: `services.linny-web.nginx = { enable; virtualHost;
  useACMEHost; }` → module zet zélf de vhost + TLS-root. Apache/caddy-gebruikers negeren dit en
  wiren zelf. Kern blijft webserver-agnostisch.
- **Timer + change-detectie** (default `3min`): `git fetch` + HEAD-compare + bouw-recept
  (`hugo=<v>;go=<v>`), skip als niets veranderd is.
- **`hugo mod get`** haalt `themeModule` (default `github.com/torreirow/linny-web-theme`,
  bumpbaar); Go in de service-PATH; module-cache in `stateDir`; `GOPROXY=direct`, `GOSUMDB=off`.
- **fence-preprocessing** (`fence.py` uit de repo) + `--configDir doesnotexist` +
  `enableGitInfo`/volledige clone: Linny-conventies, blijven behouden.

## Optie-set
| Optie          | Verplicht | Default                                 | Rol                              |
|----------------|:---------:|-----------------------------------------|----------------------------------|
| `enable`       | –         | `false`                                 | aanzetten                        |
| `gitRepo`      | ✅        | –                                       | HTTPS-URL privé linny-notes repo |
| `gitTokenFile` | ✅        | –                                       | pad naar fine-grained PAT        |
| `baseURL`      | ✅        | –                                       | `hugo --baseURL`                 |
| `webRoot`      | –         | `${stateDir}/live`                      | live-map voor de webserver       |
| `stateDir`     | –         | `/var/lib/linny-web`                    | checkout/builds/cache            |
| `user`         | –         | `linny-web`                             | service-user                     |
| `interval`     | –         | `3min`                                  | poll-timer (change-detectie)     |
| `themeModule`  | –         | `github.com/torreirow/linny-web-theme`  | te bumpen theme                  |
| `nginx.*`      | –         | disabled                                | optionele native nginx-helper    |

## Buiten scope (nu)
- **torrlinny NIET aanpassen** in deze bean. Migratie van `modules/torrlinny.nix` naar deze
  generieke module (met de Authelia-vhost eromheen) is een aparte, latere stap.
- GitHub-webhook-trigger (blijft de bestaande draft `nixos-bvhd`-lijn).

## Ship
Flake + module in `linny-web-theme`. Verplichte one-time-config voor een nieuwe gebruiker =
`gitRepo` + `gitTokenFile` + `baseURL`.

## Summary of Changes

Herbruikbare NixOS-module gebouwd in de **`linny-web-theme`**-repo (cross-repo epic; tracking hier).

**Code (repo linny-web-theme):**
- `flake.nix` — exporteert `nixosModules.linny-web` + `nixosModules.default`; input `nixpkgs`
  (nixos-26.05); plain-nix `systems` (x86_64/aarch64-linux, geen flake-utils); `checks.<system>.eval`
  die de module in een minimale NixOS-config instantieert. `flake.lock` gecommit.
- `nix/linny-web.nix` — gegeneraliseerd uit `modules/torrlinny.nix`:
  - opties: `enable, gitRepo, gitTokenFile, baseURL, webRoot, stateDir, user, branch, configFile,
    themeModule, interval` + optionele `nginx.{enable,virtualHost,useACMEHost}`. Verplicht = 3 velden.
  - build-service (oneshot): `hugo mod get` → `hugo build` (`--config`/`--configDir doesnotexist`/
    `--baseURL`) → atomic symlink-swap → keep-last-good → prune; timer met change-detectie.
  - **fine-grained PAT** via git credential-helper (token niet in argv/URL/config).
  - permissie-model: stateDir `0751`, builds `0755` + output `a+rX` (wereld-leesbaar), checkout `0700`
    (privé notities lekken niet). fence.py alleen als aanwezig.
- README "Serve it on NixOS" + CHANGELOG-entry (NEXT VERSION).

**Verificatie:** `nix flake check` → **all checks passed** (module + build-script bouwen; `webRoot`
= `/var/lib/linny-web/live`; nginx-vhost aanwezig).

**Tracking (repo torreirow-nixos):** OpenSpec change `add-linny-web-module` (proposal/design/tasks +
spec `linny-web-module`) — gevalideerd (`openspec validate --strict`) en gearchiveerd.

**Buiten scope (zoals afgesproken):** torrlinny is NIET aangepast; webhook (`nixos-bvhd`) blijft draft.
