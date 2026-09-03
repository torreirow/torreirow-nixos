# Design — torrlinny-web

## Kernbesluiten

### Overlay-frontend i.p.v. torrlinny bewerken
De frontend (thema + Pagefind) leeft NIET in de content-repo. In plaats daarvan is er een
zelfstandige Hugo-site (`modules/torrlinny/overlay/`) met eigen config + layouts + css die
torrlinny's `content/` als enige bron inleest. De build-service stelt per run een werkmap samen:
overlay-bestanden + een kopie van `content/`. Voordeel: torrlinny blijft volledig ongemoeid (geen
PaperMod, geen submodules), en de look staat volledig onder onze controle.

- `crdate` → Hugo `.Date` via `frontmatter.date = ["crdate", ...]`, zodat sorteren op datum werkt.
- Taxonomieën gedefinieerd voor customer/project/type/tag/owner/subject/doctype.

### Zoek/facet = Pagefind (client-side), geen zoekserver
Voor ~110 notities is een client-side index ruim voldoende; Meilisearch/Typesense is overkill.
Pagefind post-processt de gebouwde HTML.

- **Minify-valkuil (opgelost):** `hugo --minify` stript *lege* elementen. Filter/sort-hints staan
  daarom als **tekst-inhoud** (`<span data-pagefind-filter="customer">technative</span>`), niet als
  lege spans met `:value`. Dat is tevens de aanbevolen Pagefind-conventie.
- `data-pagefind-body` op het notitie-artikel begrenst de index tot de notitie-inhoud.
- `data-pagefind-sort="date"` levert datum-sortering; de Pagefind-UI krijgt `sort: { date: "desc" }`.

### Runtime-build, geen nix-derivation
De site-rebuild staat LOS van `nixos-rebuild switch` (die is traag/zwaar op malandro). Een systemd
oneshot bouwt op aanvraag/timer. Zo kost een notitie-wijziging geen NixOS-switch.

### Atomic swap + keep-last-good
Elke build gaat naar een verse dir `builds/<rev>-<epoch>`; daarna wordt de symlink `live` er
atomisch naartoe geswapt (`ln -sfn` + `mv -Tf`). nginx (`root = .../live`) serveert dus nooit een
half-gebouwde site. Faalt `hugo`/`pagefind` (`set -e`), dan wordt de swap nooit bereikt en blijft de
vorige goede build live. Oude builds worden gepruned (nieuwste 3 bewaren).

### Change-detectie
De timer draait elke ~3 min, maar de service doet `git fetch` + vergelijkt `HEAD` met `origin/main`
en slaat de build over als er niets veranderde (en er al een live-build staat). Poll is spotgoedkoop.

### Auth naar de privé-repo
Read-only SSH deploy key, via agenix ontsleuteld naar `/run/agenix/torrlinny-deploy-key` (owner
`torrlinny`, 0400). `GIT_SSH_COMMAND` met `IdentitiesOnly=yes`. De key is op GitHub read-only.

### Serve + auth
nginx vhost `linny.toorren.net` achter Authelia forward-auth (helper `authelia-nginx.nix`, zoals
status-page/cockpit). Privé klantnotities → nooit publiek. Wildcard-cert dekt het subdomein.

## Alternatieven overwogen
- **torrlinny bewerken (thema in de repo):** cleaner qua Hugo-idioom, maar muteert de content-repo →
  afgewezen ten gunste van de overlay (content-repo ongemoeid).
- **Meilisearch/Typesense:** krachtiger faceten, maar een extra service + index-sync; niet nodig op
  deze schaal.
- **Flake-input + Hugo in een derivation:** volledig declaratief/reproduceerbaar, maar elke
  notitie-wijziging = een trage `nixos-rebuild switch`. Afgewezen.
- **GitHub-webhook nu:** instant, maar vereist publiek endpoint + HMAC-secret; de timer is simpeler en
  self-healing. Webhook is een aparte, latere bean (hybride vangnet).
