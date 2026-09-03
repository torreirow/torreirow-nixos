## 1. Content-voorbereiding (torreirow/torrlinny, buiten deze repo)

> UITGESTELD/optioneel: omzeild door in `config.yml` óók de legacy-velden (`tag`/`tbv`/`owner`)
> te declareren → Sveltia stript niets, geen content-edit nodig. Normalisatie blijft een nette
> opschoning voor later (raakt de externe repo, buiten deze repo-local apply).

- [ ] 1.1 Frontmatter-afwijkers normaliseren: `tag` → `tags`, losse `tbv`/`owner` opschonen/wegwerken
- [ ] 1.2 Verifiëren dat over alle `content/*.md` alleen de schema-velden voorkomen (`title, crdate, customer, doctype, type, project, tags, starred, archive`)
- [ ] 1.3 Wijziging committen en naar `main` pushen; verifiëren dat de bestaande build de site schoon herbouwt

## 2. Editor-assets (Sveltia-bundle + config)

- [x] 2.1 Sveltia CMS gepind op **0.205.2**; `sveltia-cms.js` lokaal in `modules/torrlinny/admin/` (geen CDN), versie in `.sveltia-version`
- [x] 2.2 `admin/index.html` laadt de lokale `sveltia-cms.js`
- [x] 2.3 `admin/config.yml`: backend `github` op `torreirow/torrlinny`, branch `main`
- [x] 2.4 Non-recursieve folder-collectie op `content/` (submap-`_index.md` valt automatisch buiten beeld)
- [x] 2.5 Alle frontmatter-velden als widgets gedeclareerd + markdown-body (incl. legacy-velden tegen strippen)

## 3. NixOS-module (modules/torrlinny.nix)

- [x] 3.1 Admin-root = nix-store-pad (`adminDir`), buiten `live/`
- [x] 3.2 nginx-`location /admin/` toegevoegd met dezelfde `autheliaAuthConfig` als `/`
- [x] 3.3 `torrlinny-build` (reset/clean/atomic-swap) raakt de admin-root niet (aparte root buiten `live/`)
- [x] 3.4 `nixos-rebuild switch --flake .#malandro` uitgevoerd, geen fouten/cascade

## 4. Credential (fine-grained PAT) — JOUW ACTIE

- [ ] 4.1 Fine-grained GitHub PAT aanmaken: alleen repo `torreirow/torrlinny`, permission Contents read+write, verloopdatum
- [ ] 4.2 PAT-master opslaan in Vaultwarden (niet in git/nix/agenix)

## 5. Verificatie

- [x] 5.1 `/admin/` laadt achter Authelia; niet-ingelogd → 302 naar auth.toorren.net (server-zijdig geverifieerd)
- [ ] 5.2 Inloggen in Sveltia met de PAT; bestaande notitie openen (body + frontmatter-velden) — na PAT
- [ ] 5.3 Testcommit op een wegwerp-notitie: opslaan → commit op `main` → frontmatter behouden — na PAT
- [ ] 5.4 Verifiëren dat de bestaande timer de wijziging binnen ~3 min op de read-only site toont — na PAT
- [x] 5.5 Read-only deploy-key nog read-only (GitHub bevestigd); geen PAT/token in nixos-repo/nix-store

## 6. Documentatie

- [x] 6.1 `docs/torrlinny.md` uitgebreid met de editor-sectie (`/admin`, PAT-rotatie, versie-bump)
- [x] 6.2 CHANGELOG bijgewerkt onder `## NEXT VERSION` (Added: web-editor)
