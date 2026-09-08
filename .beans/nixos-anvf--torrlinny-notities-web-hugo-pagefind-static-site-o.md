---
# nixos-anvf
title: 'Torrlinny notities-web: Hugo + Pagefind static site op malandro (auto-rebuild, Authelia)'
status: completed
type: epic
priority: normal
created_at: 2026-09-03T05:20:40Z
updated_at: 2026-09-03T06:28:48Z
---

Thematische container. De privé-repo **torreirow/torrlinny** (een Hugo-gebaseerde "Linden Indexer" met markdown-notities + taxonomieën) ontsluiten als een mooie, doorzoekbare web-app op **malandro**, geserveerd door **nginx** achter **Authelia**, die **automatisch herbouwt** wanneer er naar `main` gepusht wordt.

## Doel
Mijn Linny-notities in de browser kunnen lezen/bladeren met: (1) **facet-filteren** op de taxonomieën (customer/project/type/tag/owner/subject/doctype), (2) **sorteren op datum/tijd**, en (3) **full-text zoeken** op termen in elke markdown — met een strakke layout (PaperMod eruit).

## Architectuur-besluiten (uit /opsx:explore)
- **Renderer = Hugo (houden).** Hergebruikt de bestaande `config.yaml`/layouts en de frontmatter-taxonomieën; rendert markdown netjes. Alleen het PaperMod-thema gaat eruit.
- **Zoek/facet-laag = Pagefind (client-side, statisch).** Post-processt de gebouwde HTML tot een compacte index met **facet-filters** (`data-pagefind-filter`) + **datum-sort** (`data-pagefind-sort`) + full-text, met een moderne UI. Voor ~150 notities is client-side ruim voldoende — **geen Meilisearch/zoekserver** (overkill).
- **Runtime-build, GEEN nix-derivation.** De site-rebuild staat LOS van `nixos-rebuild switch` (die is traag/zwaar). Een `torrlinny-build.service` (oneshot) doet: git pull (+submodules) -> `hugo --minify` -> `pagefind` -> **atomic swap** naar de live-map, met **keep-last-good** bij een build-fout.
- **Trigger = systemd-timer met change-detectie** (~elke 3 min: `git fetch`, HEAD==origin/main? -> skip). Self-healing, geen inbound endpoint. **Webhook komt later** (aparte child-bean, hybride vangnet).
- **Auth naar de privé-repo = read-only deploy key via agenix** (`/run/agenix/…`, malandro-conventie). Submodule-themes (PaperMod, geekdoc) zijn publiek.
- **Serve = nginx vhost `linny.toorren.net` achter Authelia** (patroon van cockpit.nix/status-page.nix). Privé klantnotities -> NIET publiek.
- **Host = malandro.** Hugo `publishDir` = `lindenIndex/` (uit hun config).

## Ship
Model A: één OpenSpec change dekt de hele epic; de child-beans spiegelen de fases voor tracking. `/cas:1shotepic` op deze epic -> OpenSpec proposal + implementatie. De **webhook-child staat op `draft`** en valt BUITEN deze eerste implementatie-run.



## Summary of Changes
Torrlinny-notities-web LIVE op linny.toorren.net (achter Authelia). Overlay-frontend (Hugo+Pagefind, torrlinny ongemoeid) + runtime build-service (git->hugo->pagefind->atomic swap, keep-last-good) + timer met change-detectie + read-only deploy key via agenix. OpenSpec change add-torrlinny-web. Webhook (nixos-bvhd) blijft draft/later.
