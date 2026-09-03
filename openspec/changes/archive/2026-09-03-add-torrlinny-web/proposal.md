## Why

De privé-repo `torreirow/torrlinny` is een Hugo-gebaseerde "Linden Indexer": markdown-notities met rijke taxonomieën (customer/project/type/tag/owner/subject/doctype) en een creatie-datum (`crdate`). Nu wordt die alleen lokaal bekeken via `hugo server` op de laptop, met het PaperMod-thema dat visueel tegenvalt. Er is geen manier om de notities vanaf malandro in de browser te lezen, te filteren op taxonomie, op datum te sorteren en full-text te doorzoeken — en niets werkt die site bij zodra er naar `main` gepusht wordt.

## What Changes

- Nieuwe NixOS-module `modules/torrlinny.nix` (geïmporteerd in `hosts/malandro/configuration.nix`).
- Een **overlay-frontend** in `modules/torrlinny/overlay/`: een zelfstandige Hugo-site (eigen `hugo.toml` + layouts + css) die ALLEEN torrlinny's `content/` inleest. De content-repo blijft ongemoeid — géén PaperMod/submodules, géén wijziging aan torrlinny.
- **Pagefind** (client-side, statisch) levert full-text zoeken, facet-filters op de taxonomieën en datum-sortering; de layouts emitteren daarvoor `data-pagefind-filter`/`data-pagefind-sort`.
- Een **runtime build-service** (`torrlinny-build.service`, oneshot — GEEN nix-derivation): sync (git) → overlay+content samenstellen → `hugo --minify` → `pagefind` → **atomic symlink-swap** naar de live-map, met **keep-last-good** bij een build-fout.
- Een **timer** (`torrlinny-build.timer`, ~elke 3 min, `Persistent`) met **change-detectie** (`git fetch` + HEAD-compare) triggert de build alleen bij een nieuwe commit.
- Read-only **deploy key** voor de privé-repo via **agenix** (`secrets/torrlinny-deploy-key.age`).
- Nieuwe nginx virtualHost `linny.toorren.net` (forceSSL + `useACMEHost "toorren.net"`) achter **Authelia** forward-auth, patroon van `status-page.nix`/`cockpit.nix`.

## Capabilities

### New Capabilities
- `torrlinny-web`: Een geauthenticeerde, statische web-view van de torrlinny-notities op `linny.toorren.net`, met facet-filteren op taxonomie, sorteren op datum en full-text zoeken, die automatisch herbouwt na een push naar `main`.

### Modified Capabilities
<!-- Geen bestaande capability-requirements wijzigen. -->

## Impact

- **Nieuw:** `modules/torrlinny.nix`, `modules/torrlinny/overlay/*` (Hugo-config + layouts + css), `secrets/torrlinny-deploy-key.age`.
- **Gewijzigd:** `hosts/malandro/configuration.nix` (import + `services.torrlinny.enable`), `secrets/secrets.nix` (recipient-regel).
- **Extern:** een read-only deploy key wordt op de GitHub-repo `torreirow/torrlinny` gezet.
- **Afhankelijkheden:** `pkgs.hugo`, `pkgs.pagefind`, `git`, `openssh`. Geen draaiend service-proces (statische output; nginx serveert de map). Geen extra firewall-poort.
- **DNS/ACME:** `linny.toorren.net` valt onder het bestaande `*.toorren.net` wildcard-certificaat.
- **Buiten scope (aparte, latere bean):** een GitHub-webhook als instant-trigger; nu doet de timer het.
