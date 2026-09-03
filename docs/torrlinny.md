# Torrlinny notities-web

Ontsluit de **privé** Hugo-repo `torreirow/torrlinny` (markdown-notities) als een
doorzoekbare statische site op **https://linny.toorren.net** (achter Authelia), die
**automatisch herbouwt** zodra er naar `main` gepusht is.

> Module: `modules/torrlinny.nix`. Ingeschakeld via `services.torrlinny.enable = true`
> in `hosts/malandro/configuration.nix`.

## Aanpak: bouw de eigen web-config van de repo (GeekDoc)

De site wordt gebouwd **exact zoals `start-web.sh` lokaal** doet: met de repo's eigen
`hugo-web.yaml` + het **hugo-geekdoc**-thema (submodule). GeekDoc levert de zijbalk/file-tree,
de **ingebouwde full-text zoek** en de taxonomie-menu's (customer/project/type/tags). We
onderhouden dus GEEN eigen layout — we hergebruiken de config die je lokaal al fijn vindt.

```
GitHub (privé main) ──[timer ~3min + change-detectie]──▶ torrlinny-build.service (user: torrlinny)
   (read-only deploy key, agenix)                          │ git pull + submodules (geekdoc-thema)
                                                           │ hugo --config hugo-web.yaml
                                                           │       --configDir doesnotexist
                                                           │       --baseURL https://linny.toorren.net/
                                                           │ atomic symlink-swap  →  live/
                                                           ▼
                                                    nginx (Authelia) ──▶ linny.toorren.net
```

- **`--configDir doesnotexist`**: voorkomt dat Hugo de `config/`-map (de Linny-JSON-indexer)
  meelaadt — alleen `hugo-web.yaml` telt. Identiek aan `start-web.sh`.
- **Submodules**: `git clone --recurse-submodules` / `git submodule update` halen `themes/hugo-geekdoc`
  (publiek) op.
- **`--baseURL`** override naar de productie-URL (de repo-config staat op localhost).
- **Runtime-build, geen nix-derivation**: een notitie-wijziging kost géén `nixos-rebuild`.
- **Kleine overlay** (`modules/torrlinny/overlay/`, bij de build in de checkout gelegd — repo blijft
  ongemoeid): notitiepagina toont **Created (crdate) + Updated (git `.Lastmod`)**; twee **paginated
  overzichten** `notes-by-{title,date}/` (secties met `layout: noteslist`); een **"Overzichten"-blok**
  in de zijbalk via een `menu.html`-override (geekdoc gebruikt géén Hugo `menu.main` maar een
  filetree). `web-extra.yaml` zet `enableGitInfo` aan (voor de git-`.Lastmod`).
- **Atomic swap + keep-last-good**: build gaat naar `builds/<rev>-<epoch>`; `live` swapt er atomisch
  naartoe. Faalt hugo, dan blijft de vorige goede build live.
- **Change-detectie**: skip als git HEAD én het bouw-recept (hugo-versie) onveranderd zijn.

## Bestanden & paden

| Pad | Rol |
|------------------------------------------|------------------------------------------------|
| `modules/torrlinny.nix` | Module: user, build-service, timer, nginx, agenix |
| `secrets/torrlinny-deploy-key.age` | Read-only SSH deploy key (agenix) |
| `/var/lib/torrlinny/checkout` | Git-checkout van torrlinny (+ submodules) |
| `/var/lib/torrlinny/builds/<rev>-<ts>` | Gebouwde sites (nieuwste 3 bewaard) |
| `/var/lib/torrlinny/live` | Symlink → huidige build (nginx `root`) |
| `/run/agenix/torrlinny-deploy-key` | Ontsleutelde deploy key (owner torrlinny, 0400) |

## Beheer

```bash
sudo systemctl start torrlinny-build.service     # handmatig (change-detectie; kan overslaan)
systemctl status torrlinny-build.timer
journalctl -u torrlinny-build.service -f
sudo readlink /var/lib/torrlinny/live            # welke build is live
```

## Belangrijke lessen

- **`keys`-groep vereist**: de build-user leest de agenix deploy-key uit `/run/keys` (`root:keys 0750`)
  → `SupplementaryGroups = [ "keys" ]` (zoals formrelay).
- **createHome uit + werkmap 0750 + nginx in de torrlinny-groep**: anders 0700 en kan nginx niet lezen.
- **`hugo-web.yaml` gebruikt hugo-geekdoc**, niet PaperMod (ondanks de comment in `start-web.sh`).
- **Deploy key = read-only** op GitHub; privé-repo → site achter Authelia (nooit publiek).
- **`--configDir doesnotexist`** is essentieel om de Linny-JSON-config buiten de web-build te houden.
- **"Last updated" = git-datum, niet fs-mtime.** Een clone/checkout stempelt alle bestanden op de
  clone-tijd (git bewaart geen mtimes). Daarom een config-override (`webConfigExtra` in de module,
  náást `hugo-web.yaml`) met `enableGitInfo: true` (→ `.Lastmod` = laatste-commit-datum) +
  `params.geekdocPageLastmod: true` (→ GeekDoc toont "Updated on …"). Vereist de **volledige** clone
  + `.git` in de source (we bouwen in de checkout). De torrlinny-repo blijft ongemoeid.

## Web-editor (`/admin`, Sveltia CMS)

`https://linny.toorren.net/admin/` is een browser-editor voor de notities (markdown-body +
frontmatter-velden), achter dezelfde Authelia-gate. **Additief** — de read-only site, de
build-service en de read-only deploy-key blijven ongemoeid.

- **Sveltia CMS**, zelf-gehost en **versie-gepind** in `modules/torrlinny/admin/` (`sveltia-cms.js`
  + `index.html` + `config.yml`; huidige versie in `.sveltia-version`). Geen CDN.
- Geserveerd als aparte nginx-`location /admin/` vanaf het **nix-store-pad** — buiten `live/`, dus
  rebuilds (`reset --hard`/`clean`/atomic-swap) raken 'm nooit.
- **Auth = PAT-login** (geen OAuth-relay/backend): je plakt 1× een **fine-grained GitHub PAT** in
  Sveltia (scope: alleen `torreirow/torrlinny`, permission **Contents: read+write**). De token leeft
  in browser-localStorage — **niet** in git/nix/agenix. Master-kopie in Vaultwarden.
- Opslaan = commit+push naar `main` → de bestaande ~3-min-timer herbouwt de read-only site.

**PAT aanmaken/roteren:** GitHub → Settings → Developer settings → Fine-grained tokens → alleen
`torrlinny`, Contents rw, verloopdatum. In Vaultwarden bewaren; bij verloop nieuwe token maken en 1×
in Sveltia plakken (geen deploy nodig).

**Sveltia-versie bumpen:** download een nieuwere `sveltia-cms.js` naar `modules/torrlinny/admin/`,
werk `.sveltia-version` bij, en `nixos-rebuild switch`. (Bewuste bump, net als kiosk-mode.js.)

## Nog te doen (aparte bean `nixos-bvhd`, draft)

GitHub-**webhook** als instant-trigger (HMAC), met de timer als vangnet. Nu doet de ~3-min-timer het.
