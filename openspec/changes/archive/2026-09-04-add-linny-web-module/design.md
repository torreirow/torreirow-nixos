# Design — add-linny-web-module

## Context

`modules/torrlinny.nix` doet al het zware werk (clone → `hugo mod get` → `hugo` → atomic swap →
nginx), maar met drie harde koppelingen: hardcoded repo-URL, agenix deploy-key en Authelia/nginx-vhost.
Deze change tilt dat patroon naar een **herbruikbare, webserver- en secrets-agnostische** module in de
`linny-web-theme`-repo, zodat theme + serveer-module samen reizen.

## Cross-repo opzet

- **Code** (flake + module) leeft in `github.com/torreirow/linny-web-theme`.
- **Tracking** (deze OpenSpec-change + epic `nixos-dhh8` + children) leeft in `torreirow-nixos`.

De flake exporteert alleen `nixosModules.*` (systeem-agnostische functies). Per-systeem outputs
(`checks`) worden met plain nix over een `systems`-lijst gemapt — **geen `flake-utils`**.

## Beslissingen

### Static build, geen `hugo server`
`hugo server` is een dev-server: watcht het filesystem (niet de git-remote), levert geen TLS/auth en
geen keep-last-good. Voor serveren ongeschikt. We houden het torrlinny-patroon: build naar
`builds/<rev>-<ts>`, dan een **atomische symlink-swap** naar `webRoot`. Faalt de build, dan blijft de
vorige `webRoot` staan (keep-last-good). Oude builds worden gepruned (nieuwste 3).

### Auth = fine-grained PAT via HTTPS
In plaats van een SSH deploy-key: HTTPS-clone met een fine-grained token (scope **Contents: read**).
Het token staat in een bestand (`gitTokenFile`); de gebruiker bepaalt zelf hoe dat daar komt
(agenix/sops/plain). De clone/fetch gebruikt een **git credential-helper** die het token pas op
auth-tijd uit het bestand leest:

```
git -c credential.helper='!f() { test "$1" = get && \
    printf "username=x-access-token\npassword=%s\n" "$(cat <gitTokenFile>)"; }; f' ...
```

Alleen het *pad* staat op de command-line; het token zelf komt **niet** in de repo-URL, de
proceslijst (`ps`), of de on-disk git-config.

### Permissie-model (privé notities, publieke output)
De build-output moet leesbaar zijn voor een **onbekende** webserver-user → wereld-leesbaar
(`chmod -R a+rX` op de build-map). Maar de checkout bevat privé notities. Oplossing:

| Pad                     | Perm   | Reden                                                        |
|-------------------------|--------|-------------------------------------------------------------|
| `stateDir`              | `0751` | traverseerbaar (webserver bereikt `builds/`), niet listbaar |
| `stateDir/builds`       | `0755` | webserver kan de build-map betreden                         |
| `stateDir/builds/<x>`   | `a+rX` | gerenderde site is leesbaar voor elke webserver             |
| `stateDir/checkout`     | `0700` | privé notities blijven privé                                |
| caches (`go`, `hugo_*`) | privé  | onder de `0751` stateDir, niet publiek gelist               |

Zo hoeft de module niets te weten van de webserver-user/groep en lekt de checkout niet.

### Webserver-agnostisch + optionele nginx-helper
De module **publiceert** `webRoot` als optie-waarde (default `${stateDir}/live`). De gebruiker legt
zelf de koppeling: `services.nginx.virtualHosts.X.root = config.services.linny-web.webRoot` (of de
apache/caddy-variant). Voor het nginx-geval biedt de module een optionele helper
`services.linny-web.nginx = { enable; virtualHost; useACMEHost; }` die de vhost + TLS-root zelf zet.

### Linny-conventies (behouden)
- `hugo mod get <themeModule>` (default `github.com/torreirow/linny-web-theme`), `go` in PATH,
  module-cache in `stateDir`, `GOPROXY=direct`, `GOSUMDB=off`.
- `hugo --config <configFile> --configDir doesnotexist --baseURL <baseURL>` (configFile default
  `hugo-web.yaml`); `--configDir doesnotexist` houdt de Linny-JSON-indexer buiten de web-build.
- **fence-preprocessing** (`fence.py`) draait **alleen als het bestand in de checkout bestaat**
  (generieke notebooks hebben het niet per se).
- `enableGitInfo`/`.Lastmod` vereist de volledige clone (met `.git`).

## Verificatie

- `nix flake check` op de theme-repo (evalueert de eval-check die de module in een voorbeeld-
  NixOS-config instantieert en de build-service-unit + `webRoot`-optie evalueert).
- Nix-formattering/eval schoon.
- Een volledige runtime-build (echte clone + hugo) is host-afhankelijk (token + netwerk) en valt
  buiten de flake-check; de eval-check dekt de module-structuur.

## Non-goals

- torrlinny migreren naar deze module (aparte, latere bean).
- GitHub-webhook-trigger (`nixos-bvhd`, draft).
- Multi-instance (meerdere notebooks per host) — één `services.linny-web` volstaat nu.
