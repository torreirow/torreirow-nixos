## Why

De Torrlinny-notities kunnen nu alleen lokaal (vim op lobos) bewerkt en via git gepusht worden;
`linny.toorren.net` is bewust read-only. Er is behoefte om notities óók vanuit de browser te
kunnen bewerken (inclusief de gestructureerde frontmatter), zonder de git-repo als bron van
waarheid los te laten en zonder de bestaande read-only site of de read-only deploy-key aan te tasten.

## What Changes

- **Sveltia CMS als `/admin`-editor** naast de bestaande site op dezelfde vhost `linny.toorren.net`,
  als aparte nginx-`location` met een eigen root buiten de Hugo-build-output (zodat rebuilds de
  editor nooit overschrijven).
- **Zelf-gehoste, versie-gepinde Sveltia-bundle** (`index.html` + `config.yml` + `sveltia-cms.js`),
  geen CDN-afhankelijkheid — dezelfde aanpak als `kiosk-mode.js` bij Home Assistant.
- **Authelia-gate hergebruikt** op `/admin` (voorlopig: iedereen die door Authelia komt mag editen).
- **PAT-login (geen OAuth-relay, geen backend)**: Sveltia authenticeert met een fine-grained GitHub
  Personal Access Token (scope: alleen `torreirow/torrlinny`, permission Contents read+write). De
  token leeft in de browser (localStorage); de master-kopie in Vaultwarden.
- **`config.yml`-schema**: één platte folder-collectie op `content/` (non-recursief, zodat de
  taxonomy-/overlay-`_index.md` in submappen buiten beeld blijven), met álle waargenomen
  frontmatter-velden gedeclareerd (`title`, `crdate`, `customer`, `doctype`, `type`, `project`,
  `tags`, `starred`, `archive`) om strippen van niet-gedeclareerde velden te voorkomen.
- **Eenmalige frontmatter-opschoning** in de torrlinny-repo: normaliseer de afwijkers
  (`tag` → `tags`, losse `tbv`/`owner`) zodat het schema dekkend en strip-vrij is.
- **Commit/push → GitHub → bestaande 3-min build-timer** pikt de wijziging op en herbouwt de
  read-only site. Geen wijziging aan het build-recept nodig.

Niet in scope: OAuth-relay/multi-user login met eigen GitHub-identiteit, instant-rebuild-webhook
(blijft de aparte bean `nixos-bvhd`), afbeeldingen/bijlagen-upload, verhuizen van de repo naar Gitea.

## Capabilities

### New Capabilities
- `torrlinny-web-editor`: geauthenticeerde browser-editor op `linny.toorren.net/admin` waarmee de
  torrlinny-notities (markdown-body + gestructureerde frontmatter) bewerkt en als git-commit naar
  `torreirow/torrlinny` gepusht worden, waarna de bestaande read-only site automatisch herbouwt.

### Modified Capabilities
<!-- Geen. De bestaande `torrlinny-web`-requirements (read-only view, filteren, zoeken,
     auto-rebuild) blijven ongewijzigd; de editor is puur additief op een aparte `/admin`-location. -->

## Impact

- **Nieuw/gewijzigd**: `modules/torrlinny.nix` (extra nginx-`location /admin` + tmpfiles voor de
  admin-root), een gepinde Sveltia-bundle + `admin/config.yml`, `docs/torrlinny.md` (editor-sectie).
- **Nieuwe credential**: fine-grained GitHub PAT (Contents rw, alleen torrlinny) — beheerd in
  Vaultwarden, leeft in de browser; NIET in git/nix. Los van de read-only deploy-key.
- **Externe repo**: eenmalige frontmatter-normalisatie in `torreirow/torrlinny` (buiten deze
  nixos-repo).
- **Onaangetast**: de read-only Hugo-site (`location /`), de `torrlinny-build`-service/timer, de
  read-only deploy-key en het atomic-swap/keep-last-good-mechanisme.
