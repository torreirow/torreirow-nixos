# Torrlinny notities-web

Ontsluit de **privé** Hugo-repo `torreirow/torrlinny` (markdown-notities) als een
doorzoekbare statische site op **https://linny.toorren.net** (achter Authelia), die
**automatisch herbouwt** zodra er naar `main` gepusht is.

> **Sinds de migratie (feature `nixos-9596`)** is `modules/torrlinny.nix` een **dunne wrapper**
> rond de gedeelde, herbruikbare **`services.linny-web`** module (flake
> `github:torreirow/linny-web-theme`, geïmporteerd via de malandro modules-lijst in `flake.nix`).
> De clone/build/atomic-swap/keep-last-good/timer + het permissie-model zitten nu in díé module;
> de wrapper voegt alleen het malandro-specifieke toe: de agenix SSH-deploy-key, de Authelia-vhost
> en `domain`/`acmeHost`. De systemd-unit heet daardoor nu **`linny-web-build.service`** (niet meer
> `torrlinny-build`). De werkmap blijft `/var/lib/torrlinny`.

> Module: `modules/torrlinny.nix`. Ingeschakeld via `services.torrlinny.enable = true`
> in `hosts/malandro/configuration.nix`.

## Aanpak: bouw met de gedeelde linny-web-theme Hugo-module

De site wordt gebouwd met de repo's eigen `hugo-web.yaml`, die de **[linny-web-theme](https://github.com/torreirow/linny-web-theme)**
Hugo-module importeert. Die module **bundelt geekdoc** (prebuilt) én levert de
Linny-layouts: de **taxonomie-zijbalk** (customer/project/type/tags met counts), de
per-notitie **Created + Updated**-datums, de twee **overzichtspagina's** en de
config-`params`. GeekDoc levert daarbovenop de ingebouwde full-text zoek. We
onderhouden dus **geen eigen overlay** meer op malandro — dat zit nu in de theme,
herbruikbaar voor álle Linny-notebooks (zie epic `nixos-al4j`).

```
GitHub (privé main) ──[timer ~3min + change-detectie]──▶ torrlinny-build.service (user: torrlinny)
   (read-only deploy key, agenix)                          │ git fetch/reset main
                                                           │ hugo mod get  (linny-web-theme, Go in PATH)
                                                           │ fence.py (box-drawing CLI → ```text)
                                                           │ hugo --config hugo-web.yaml
                                                           │       --configDir doesnotexist
                                                           │       --baseURL https://linny.toorren.net/
                                                           │ atomic symlink-swap  →  live/
                                                           ▼
                                                    nginx (Authelia) ──▶ linny.toorren.net
```

- **`hugo mod get`**: haalt de theme-module (gepind in de repo's `go.mod`/`go.sum`).
  Vereist `go` in de service-PATH (`path = [... go]`); module-cache staat in
  `/var/lib/torrlinny/go` + `hugo_cache`. `GOPROXY=direct` (rechtstreeks van GitHub),
  `GOSUMDB=off` (integriteit via de gecommitte `go.sum`).
- **`--configDir doesnotexist`**: voorkomt dat Hugo de `config/`-map (de Linny-JSON-indexer)
  meelaadt — alleen `hugo-web.yaml` telt.
- **`--baseURL`** override naar de productie-URL (de repo-config staat op localhost).
- **`enableGitInfo`** staat in torrlinny's `hugo-web.yaml` (root-key — mergt NIET uit een
  theme). Vereist de **volledige** clone + `.git` in de source (we bouwen in de checkout).
- **fence-preprocessing**: `fence.py` (uit de repo) wikkelt CLI-output met box-drawing
  tekens (bv. `aws … --output table`, U+2500–U+259F) in een ```text-fence. In-place op de
  wegwerp-checkout (zodat `.git`/`.Lastmod` intact blijft), idempotent; de bron-repo blijft
  ongemoeid.
- **Runtime-build, geen nix-derivation**: een notitie-wijziging kost géén `nixos-rebuild`.
- **Atomic swap + keep-last-good**: build gaat naar `builds/<rev>-<epoch>`; `live` swapt er
  atomisch naartoe. Faalt hugo, dan blijft de vorige goede build live.
- **Change-detectie**: skip als git HEAD én het bouw-recept (`hugo=<v>;go=<v>`) onveranderd zijn.

## Bestanden & paden

| Pad | Rol |
|------------------------------------------|------------------------------------------------|
| `modules/torrlinny.nix` | Wrapper: agenix SSH-key + `services.linny-web` + Authelia-vhost |
| `linny-web-theme:nix/linny-web.nix` | Gedeelde module: user, build-service, timer, permissies |
| `secrets/torrlinny-deploy-key.age` | Read-only SSH deploy key (agenix) |
| `/var/lib/torrlinny/checkout` | Git-checkout van torrlinny |
| `/var/lib/torrlinny/go`, `…/hugo_cache` | Go/Hugo-module-cache (theme) |
| `/var/lib/torrlinny/builds/<rev>-<ts>` | Gebouwde sites (nieuwste 3 bewaard) |
| `/var/lib/torrlinny/live` | Symlink → huidige build (nginx `root`) |
| `/run/agenix/torrlinny-deploy-key` | Ontsleutelde deploy key (owner torrlinny, 0400) |

De web-layouts/geekdoc/overzichtspagina's leven **niet** meer in deze repo maar in de
theme-module `github.com/torreirow/linny-web-theme` (torrlinny's `hugo-web.yaml` importeert 'm).

## Beheer

```bash
sudo systemctl start linny-web-build.service     # handmatig (change-detectie; kan overslaan)
systemctl status linny-web-build.timer
journalctl -u linny-web-build.service -f
sudo readlink /var/lib/torrlinny/live            # welke build is live
```

De wrapper-config staat in `modules/torrlinny.nix`; de generieke logica in de
`linny-web`-module (repo `linny-web-theme`, `nix/linny-web.nix`).

De theme bumpen (nieuwe versie): in de **torrlinny-repo** `hugo mod get -u github.com/torreirow/linny-web-theme`
(werkt `go.mod`/`go.sum` bij), commit + push → de volgende malandro-build pikt het op.

## Belangrijke lessen

- **Hugo merget alleen `params` uit een theme.** taxonomies/menu/markup/frontmatter/
  pagination/`enableGitInfo` mergen NIET → die staan in torrlinny's `hugo-web.yaml`. De
  geekdoc-`params` (incl. `geekdocPageLastmod`) komen wél uit de theme.
- **`go` vereist in de service-PATH** voor `hugo mod get` (Hugo-modules resolven via de
  Go-toolchain). Module-cache in de persistente werkmap zodat niet elke build opnieuw fetcht.
- **`keys`-groep vereist**: de build-user leest de agenix deploy-key uit `/run/keys`
  (`root:keys 0750`) → `SupplementaryGroups = [ "keys" ]` (zoals formrelay).
- **createHome uit + werkmap 0750 + nginx in de torrlinny-groep**: anders 0700 en kan nginx niet lezen.
- **Deploy key = read-only** op GitHub; privé-repo → site achter Authelia (nooit publiek).
- **`--configDir doesnotexist`** is essentieel om de Linny-JSON-config buiten de web-build te houden.
- **"Updated" = git-datum, niet fs-mtime** (`enableGitInfo` → `.Lastmod`). Vereist de volledige
  clone + `.git` in de source. Fence draait daarom in-place op de checkout, niet op een kopie.

## Nog te doen (aparte bean `nixos-bvhd`, draft)

GitHub-**webhook** als instant-trigger (HMAC), met de timer als vangnet. Nu doet de ~3-min-timer het.
