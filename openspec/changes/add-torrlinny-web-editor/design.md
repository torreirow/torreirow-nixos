## Context

Zie proposal.md — Why. Relevante huidige toestand en beperkingen:

- `modules/torrlinny.nix` bouwt de site runtime (systemd oneshot + timer, change-detectie), doet
  `git reset --hard origin/main` + `git clean -fd layouts content`, en swapt atomisch een symlink
  `live/` → `builds/<rev>`. Alles onder `live/` wordt dus per build weggegooid/vervangen.
- De build gebruikt een **read-only** GitHub deploy-key (agenix). Schrijven vereist een aparte credential.
- nginx serveert `linny.toorren.net` achter Authelia via de helper `modules/authelia-nginx.nix`
  (`autheliaVerifyLocation` + `autheliaAuthConfig`). nginx zit in de `torrlinny`-groep om `live/` te lezen.
- De notities staan **plat** in `content/` (~110 `.md`, bestandsnaam = slug). Taxonomy- en
  overlay-indexpagina's zijn `_index.md`-bestanden in **submappen** (`content/{customer,project,type,tags}`
  en `content/notes-by-{title,date}`). Waargenomen frontmatter-keys: `title, crdate, doctype, customer,
  type, project, starred, archive` + enkele afwijkers (`tag, tbv, owner`).
- Sveltia CMS is een enkele client-side JS-bundle die via de git-provider-API commit; het ondersteunt
  **PAT-login** als de enige gebruiker de tokens beheert (geen OAuth-relay nodig).

## Goals / Non-Goals

**Goals:**
- Editor additief naast de bestaande site, zonder de read-only view, build-service of deploy-key te raken.
- Geen extra backend/relay en geen OAuth-app: schrijven via een fine-grained PAT in de browser.
- Reproduceerbaar/declaratief in NixOS; editor-assets zelf-gehost en versie-gepind.
- Frontmatter bewerkbaar als velden, zonder verlies van bestaande velden.

**Non-Goals (design-niveau):**
- Multi-user met eigen GitHub-identiteit per editor (OAuth-relay) — later, indien nodig.
- Instant-rebuild-webhook — blijft de aparte bean `nixos-bvhd`; hier volstaat de 3-min-timer.
- Media/afbeeldingen-upload; repo-migratie naar Gitea.

## Decisions

### D1: Sveltia CMS met PAT-login (geen relay, geen backend)
Sveltia authenticeert met een fine-grained GitHub PAT; de browser praat rechtstreeks met de GitHub-API.
- **Waarom**: minimale infra — één statische bundle + een token. Past bij single-user-achter-Authelia.
- **Alternatieven**: (a) self-hosted OAuth-relay (systemd) — nodig bij multi-user, nu overkill;
  (b) Cloudflare Worker `sveltia-cms-auth` — off-box, botst met in-house-lijn; (c) bespoke editor-backend
  — meer bouw/onderhoud + groter aanvalsvlak; (d) Decap i.p.v. Sveltia — ouder, minder mobiel-vriendelijk.

### D2: `/admin` als aparte nginx-location met eigen root buiten `live/`
Nieuwe `location /admin` met root op een vaste, door tmpfiles/nix beheerde map (bv. `${dataDir}/admin`
of een nix-store-pad), met dezelfde `autheliaAuthConfig` als `/`.
- **Waarom**: de build swapt/wist `live/`; assets daarbuiten overleven elke rebuild. Zelfde vhost →
  hergebruik van de bestaande Authelia-gate en cert.
- **Alternatief**: apart subdomein `edit.linny.toorren.net` — extra vhost/cert-config zonder functioneel
  voordeel. Verworpen voor de eenvoud.

### D3: Zelf-gehoste, gepinde bundle (geen CDN)
`sveltia-cms.js` op een expliciete versie + `index.html` + `admin/config.yml` lokaal serveren.
- **Waarom**: geen externe-CDN-afhankelijkheid/breakage, werkt volledig achter Authelia, reproduceerbaar.
  Zelfde patroon als `kiosk-mode.js` bij Home Assistant. Updaten is een bewuste versie-bump.

### D4: `config.yml` — één non-recursieve folder-collectie op `content/`
Folder-collectie op `content` (non-recursief) pakt exact de platte notes; de `_index.md` in submappen
vallen automatisch buiten beeld. Alle waargenomen frontmatter-velden expliciet declareren.
- **Waarom**: voorkomt dat niet-gedeclareerde velden bij opslaan gestript worden, en houdt de
  taxonomy/overlay-pagina's uit de editor.
- **Velden**: `title` (string, required), `crdate` (date, default now), `customer` (select/relation),
  `doctype` (select), `type` (select/string), `project` (string), `tags` (list), `starred` (bool),
  `archive` (bool), body (markdown). `search.md` wegfilteren of negeren.

### D5: Eenmalige frontmatter-normalisatie in `torreirow/torrlinny`
Vóór/rond go-live `tag`→`tags` en losse `tbv`/`owner` opschonen (buiten deze nixos-repo).
- **Waarom**: maakt het schema dekkend en strip-vrij; kleine, geïsoleerde content-commit.

### D6: PAT-beheer buiten nix
Fine-grained PAT (Contents rw, alleen `torreirow/torrlinny`), master-kopie in Vaultwarden, leeft in
browser-localStorage. Niet in nixos-repo/nix-store/agenix.
- **Waarom**: de token is per-apparaat/per-gebruiker en roteerbaar; hoort niet in de gedeelde config.

## Risks / Trade-offs

- **Sveltia stript niet-gedeclareerde frontmatter bij opslaan** → mitigatie: álle velden declareren
  (D4) + vóór go-live testen op een wegwerp-notitie of frontmatter behouden blijft.
- **Concurrency met lokale vim-edits** (git-sync/bidirectioneel + web-edit op hetzelfde bestand) →
  non-fast-forward/merge-conflict aan de lobos-kant → mitigatie: solo-discipline "pull vóór lokaal
  bewerken"; Sveltia werkt tegen de laatste `main` via de API.
- **PAT in browser-localStorage** → mitigatie: fine-grained + repo-scoped + achter Authelia + verloop
  (90 dagen of max 1 jaar) + master in Vaultwarden; rotatie = nieuwe token plakken.
- **Schrijfpad naar privé-repo vanaf het web** → mitigatie: Authelia-gate op `/admin`, geen server-side
  token (browser-only), read-only deploy-key blijft gescheiden.
- **Rebuild-latency ~3 min** (geen instant feedback) → geaccepteerd; instant is de latere webhook-bean.
- **Sveltia-versie-pin veroudert** → mitigatie: bewuste periodieke versie-bump (bundle opnieuw
  downloaden), zoals gedocumenteerd voor kiosk-mode.js.

## Migration Plan

1. Frontmatter-normalisatie in `torreirow/torrlinny` (D5), pushen naar `main`.
2. Gepinde Sveltia-bundle + `index.html` + `admin/config.yml` toevoegen aan de nixos-repo.
3. `modules/torrlinny.nix` uitbreiden: admin-root (tmpfiles/nix) + `location /admin` met Authelia.
4. `nixos-rebuild switch` op malandro; visueel verifiëren `/admin` laadt achter Authelia.
5. Fine-grained PAT aanmaken (Vaultwarden), 1× in Sveltia plakken; testcommit op een wegwerp-notitie;
   verifieer commit op GitHub + dat frontmatter behouden blijft + dat de site na de timer herbouwt.
6. `docs/torrlinny.md` bijwerken met de editor-sectie + PAT-rotatie-notitie.

**Rollback**: verwijder de `location /admin` (+ admin-root) en rebuild — de read-only site, build en
deploy-key zijn onaangetast. Intrekken van de PAT ontneemt onmiddellijk alle schrijftoegang.
