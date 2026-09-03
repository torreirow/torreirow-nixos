# Torrlinny notities-web

Ontsluit de **privé** Hugo-repo `torreirow/torrlinny` (markdown-notities met taxonomieën) als een
strakke, doorzoekbare statische site op **https://linny.toorren.net** (achter Authelia), die
**automatisch herbouwt** zodra er naar `main` gepusht is.

> Module: `modules/torrlinny.nix` (+ overlay `modules/torrlinny/overlay/`). Ingeschakeld via
> `services.torrlinny.enable = true` in `hosts/malandro/configuration.nix`.

## Architectuur

```
GitHub (privé main) ──[timer ~3min + change-detectie]──▶ torrlinny-build.service (user: torrlinny)
   (read-only deploy key, agenix)                          │ git pull  →  overlay + content
                                                           │ hugo --minify  →  pagefind
                                                           │ atomic symlink-swap  →  live/
                                                           ▼
                                                    nginx (Authelia) ──▶ linny.toorren.net
```

- **Overlay-frontend:** een zelfstandige Hugo-site (`overlay/`: eigen config + layouts + css) die
  ALLEEN torrlinny's `content/` inleest. De content-repo blijft ongemoeid (geen PaperMod/submodules).
- **Pagefind** (client-side): full-text zoeken + facet-filters (customer/project/type/tag/owner/
  subject/doctype) + datum-sort. De layouts emitteren `data-pagefind-filter`/`-sort` als **tekst-
  inhoud** (niet lege spans) zodat `hugo --minify` ze niet wegstript.
- **Runtime-build, geen nix-derivation:** een notitie-wijziging kost géén `nixos-rebuild`.
- **Atomic swap + keep-last-good:** elke build gaat naar `builds/<rev>-<epoch>`; `live` wordt er
  atomisch naartoe geswapt. Faalt hugo/pagefind, dan blijft de vorige goede build live.
- **crdate → .Date:** `frontmatter.date = ["crdate", …]` zodat sorteren op datum werkt.

## Bestanden & paden

| Pad | Rol |
|------------------------------------------|------------------------------------------------|
| `modules/torrlinny.nix` | Module: user, build-service, timer, nginx, agenix |
| `modules/torrlinny/overlay/` | Hugo-overlay (hugo.toml, layouts/, static/css) |
| `secrets/torrlinny-deploy-key.age` | Read-only SSH deploy key (agenix) |
| `/var/lib/torrlinny/checkout` | Git-checkout van torrlinny (content-bron) |
| `/var/lib/torrlinny/builds/<rev>-<ts>` | Gebouwde sites (nieuwste 3 bewaard) |
| `/var/lib/torrlinny/live` | Symlink → huidige build (nginx `root`) |
| `/run/agenix/torrlinny-deploy-key` | Ontsleutelde deploy key (owner torrlinny, 0400) |

## Beheer

```bash
# Handmatig herbouwen (change-detectie; --force negeert dat)
sudo systemctl start torrlinny-build.service
sudo systemctl start torrlinny-build.service   # (script arg --force via override indien nodig)

# Status/logs
systemctl status torrlinny-build.timer
journalctl -u torrlinny-build.service -f

# Welke build is live?
readlink /var/lib/torrlinny/live
```

## Belangrijke lessen

- **`keys`-groep vereist:** de build-service draait als user `torrlinny` en moet `/run/keys`
  (`root:keys 0750`) kunnen betreden om de agenix deploy-key te lezen → `SupplementaryGroups = [ "keys" ]`
  (zelfde patroon als formrelay).
- **Minify stript lege elementen:** Pagefind-filter/sort als tekst-inhoud emitteren, niet als lege spans.
- **Deploy key = read-only** op GitHub; privé-repo, dus site achter Authelia (nooit publiek).

## Nog te doen (aparte bean `nixos-bvhd`, draft)

GitHub-**webhook** als instant-trigger (HMAC), met de timer als vangnet. Nu doet de ~3-min-timer het.
