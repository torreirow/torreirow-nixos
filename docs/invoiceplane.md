# InvoicePlane Docker (invoices.toorren.net)

OCI-container op poort 8092, host-MariaDB, de .htaccess-workaround en proxy-header-les.

> Verplaatst uit CLAUDE.md (Huidige Status) om de sessie-context slank te houden.

### Sessie 2026-04-26 - InvoicePlane Docker setup - OPGELOST

**Doel:** InvoicePlane (open source facturatie platform) toevoegen aan malandro via Docker.

**Configuratie:**
- **URL:** `https://invoices.toorren.net`
- **Port:** 8092 (localhost binding)
- **Container:** `funktionslust/invoiceplane:latest`
- **Database:** Bestaande MariaDB op host (localhost)
  - Database: `invoiceplane`
  - Gebruiker: via `secrets/invoiceplane-env.age`
  - Wachtwoord: via `secrets/invoiceplane-env.age`
- **Authenticatie:** Authelia (verplicht)

**Problemen opgelost:**

1. **Port conflict (8084)**
   - Probleem: Port 8084 was al in gebruik door Pi-hole FTL
   - Oplossing: InvoicePlane verplaatst naar port 8092
   - `PORTS.md` bijgewerkt met DocSeal (8090) en InvoicePlane (8092)

2. **Bad Request (400) via nginx**
   - Probleem: Apache gaf "Bad Request" bij requests via nginx
   - Diagnose: Dubbele proxy headers (handmatig + NixOS `recommendedProxySettings`)
   - Oplossing: Handmatige proxy headers verwijderd, NixOS voegt ze automatisch toe

3. **404 Not Found voor /welcome route**
   - Probleem: InvoicePlane routes gaven 404 (bijv. `/welcome`)
   - Diagnose: `.htaccess` bestand ontbrak (bestaat als `htaccess` zonder punt)
   - Root cause: `REMOVE_INDEXPHP=true` env var werkt niet in dit Docker image
   - Oplossing: `ExecStartPost` script dat `htaccess` naar `.htaccess` kopieert bij container start

3. **Module structuur**
   - Van docker-compose naar OCI containers (zoals DocSeal)
   - Alle configuratie via age-encrypted environment file
   - Nginx virtualHost direct in module

**Bestanden gewijzigd:**
- `modules/invoiceplane-docker.nix` - Nieuwe module (OCI containers)
- `hosts/malandro/configuration.nix` - Module import toegevoegd
- `secrets/invoiceplane-env.age` - Database credentials (encrypted)
- `PORTS.md` - DocSeal (8090) en InvoicePlane (8092) toegevoegd

**Belangrijke lessen:**
- ✅ Gebruik OCI containers in plaats van docker-compose voor nieuwe services
- ✅ Check `PORTS.md` voor vrije poorten voordat je een service toevoegt
- ✅ NixOS voegt automatisch proxy headers toe via `recommendedProxySettings` - stel deze niet handmatig in
- ✅ Docker containers kunnen host MariaDB bereiken via `host.docker.internal` (met `--add-host=host.docker.internal:host-gateway`)
- ✅ Nginx reverse proxy betekent NIET dat .htaccess niet nodig is - Apache in de container heeft nog steeds .htaccess nodig voor routing
- ✅ Docker image bugs kunnen workarounds vereisen (zoals ExecStartPost voor .htaccess setup)

**Status:** ✅ InvoicePlane live op https://invoices.toorren.net

### Sessie 2026-10-16 - 500 op /settings (invoices.wereldvanbegrip.nl) - OPGELOST

**Symptoom:** `https://invoices.wereldvanbegrip.nl/settings` gaf 500 Internal Server Error.

**Diagnose:** app-log in de container (`/var/www/html/application/logs/log-<datum>.php`):
```
Mdl_Templates::remove_extension(): Argument #1 ($files) must be of type array, bool given
```
De bind-mount `/data/external/invoiceplane-docker/quote_templates` → `application/views/quote_templates`
was leeg. De mount verbergt de `pdf/`- en `public/`-submappen uit het image; `directory_map()` op een
niet-bestaande map geeft `false` en de settings-pagina crasht.

**Oplossing:**
- Standaard quote-templates uit het image naar de hostmap gekopieerd:
  ```bash
  cid=$(sudo docker create funktionslust/invoiceplane:latest)
  sudo docker cp "$cid":/var/www/html/application/views/quote_templates/. /data/external/invoiceplane-docker/quote_templates/
  sudo docker rm "$cid"; sudo chown -R 33:33 /data/external/invoiceplane-docker/quote_templates
  ```
- tmpfiles-regels in `modules/invoiceplane-docker.nix` voor `pdf/` en `public/` onder zowel
  `templates/` als `quote_templates/`, zodat een lege mount nooit meer tot een crash leidt.
  Let op: een lege map voorkomt de crash, maar dan staan er geen templates in de keuzelijst; vul
  'm dan met bovenstaande `docker cp` (voor `invoice_templates` analoog).

**Open punt:** in Settings staat PDF-factuurtemplate `WereldVanBegrip` ingesteld, maar
`templates/pdf/WereldVanBegrip.php` bestaat niet → InvoicePlane valt terug op het default template
(`Invalid PDF invoice template from settings: WereldVanBegrip, using default`).

**Les:** bind-mount je een map over een image-map, dan verdwijnt de image-inhoud. Seed de hostmap
eerst vanuit het image.

**Logo op de webfactuur (`/guest/view/invoice/...`) te groot:** `InvoicePlane_Web.php` echoot het
logo (`wvb-klein-logo2.png`, 488×727) zonder maat. In
`/data/external/invoiceplane-docker/templates/public/InvoicePlane_Web.php` is de `<img>` nu begrensd
op `max-height:120px` (backup: `InvoicePlane_Web.php.bak-20261016`). Het bestand staat op de
hostmap, dus de wijziging blijft bewaard als het image wordt bijgewerkt.

**Nieuw factuurlogo (2026-10-16):** `wvb-logo-transparant.png` (270×400, 112 KB), gemaakt uit de
2000×2000-bron met `magick ... -trim +repage -resize x400 -strip` + `oxipng -o 4`. Ingesteld via
`ip_settings.invoice_logo`; het oude `wvb-klein-logo2.png` staat er nog.

**Logo's op de overige plekken (2026-10-16):**

| Plek                          | Bron                                    | Maat                                       |
| ----------------------------- | --------------------------------------- | ------------------------------------------ |
| Factuur/offerte PDF           | `invoice_logo` → `wvb-logo-transparant` | CSS `#invoice-logo{max-height:125px}`      |
| Factuur/offerte webweergave   | `invoice_logo`                          | `max-height:120px` in `*_templates/public` |
| Inlogscherm                   | `login_logo` → `wvb-login-logo.png`     | 122×180                                    |
| Favicon                       | `branding/favicon.png` (bind-mount)     | 64×64                                      |
| Gast-betaalpagina             | `invoice_logo`, view in image           | niet begrensd (zelden gebruikt)            |

Logo's maken: `magick /data/external/invoiceplane-docker/branding/logo-wvb-bron-2000.png -trim +repage -resize x<hoogte> -strip <uit>`
(favicon: `-resize 64x64 -background none -gravity center -extent 64x64`), daarna `oxipng -o 4`.

**HTML-mailtemplate (2026-10-16):** `ip_email_templates` id 1 ("Factuur Maandelijks") is nu opgemaakte
HTML (inline styles, tabel-layout, logo via absolute URL, knop naar `{{{invoice_guest_url}}}`) en
staat als standaard ingesteld (`ip_settings.email_invoice_template = 1`). PDF-template van de mail
van het niet-bestaande `WereldVanBegrip` naar `InvoicePlane` gezet. Mailer.php slaat `nl2br` over
zodra de body HTML bevat, dus regeleinden in de HTML zijn veilig. Backup van de oude tabel:
`/data/external/invoiceplane-docker/branding/ip_email_templates-backup-20261016.sql`.

**Mailtemplates bijgewerkt (2026-10-16, later):** drie HTML-templates, alle drie gegenereerd door
`/data/external/invoiceplane-docker/branding/gen_mails.py <uitmap>` (schrijft `mail-templates.sql` +
`preview-*.html`; toepassen met `sudo mariadb invoiceplane < mail-templates.sql`, idempotent op titel):

| Id | Titel                        | Instelling                       | PDF-template           |
| -- | ---------------------------- | -------------------------------- | ---------------------- |
| 1  | Factuur Maandelijks          | `email_invoice_template`         | InvoicePlane           |
| 2  | Herinnering verlopen factuur | `email_invoice_template_overdue` | InvoicePlane - overdue |
| 3  | Offerte                      | `email_quote_template`           | InvoicePlane           |

De **Voorbeeld**-pane toonde HTML-mails als ruwe code (opgelost met Gabbaya-patch 0003): `update_email_template_preview()`
in `assets/core/js/scripts.js` haalt de body eerst door `encodeHtml()` en strip daarna `style` en `<img>`.
Bug in InvoicePlane zelf; de verstuurde mail is wél opgemaakt. Controleer via een testmail of de
`preview-*.html` uit het script.

**Image vastgepind (2026-10-16):** `funktionslust/invoiceplane@sha256:8fa4726e…` (= de `latest` die op dat
moment draaide). Bij upgraden: settings-pagina, templates en `.htaccess`-workaround opnieuw controleren.

### 2026-10-16 - Beheer weer achter Authelia (LIVE)

Aanleiding: 1.7.1 heeft bekende critical/high lekken (RCE via templates, niet-verlopende reset-tokens,
SQLi, IDOR op gast-offertes) en stond sinds de verhuizing naar wereldvanbegrip.nl zonder Authelia publiek.

- `invoices.wereldvanbegrip.nl/` → Authelia `two_factor`, groep **`invoiceplane`** (`wouter` zit erin).
- Publiek (geen `auth_request` in nginx): `/guest/`, `/assets/`, `~ ^/uploads/[^/]+\.(png|jpe?g)$`
  (logo's voor de mails). `/uploads/archive/` e.d. zitten achter Authelia.
- **Eigen cookie-domein:** een Authelia-cookie van `toorren.net` geldt niet op `wereldvanbegrip.nl`,
  dus tweede `session.cookies`-entry + portal-vhost **`auth.wereldvanbegrip.nl`** (DNS A → 82.170.93.180,
  wildcard-cert `*.wereldvanbegrip.nl`). Zelfde Authelia, zelfde users/2FA; je logt per domein één keer in.
- Backup vóór de wijziging: `/data/external/invoiceplane-backup-20261016` (bestanden + DB-dump + ipconfig.php).

Geverifieerd: `/` en `/settings` → 302 naar `auth.wereldvanbegrip.nl`; gastlink, logo, favicon → 200.
Open: upgrade naar 1.7.2 zodra funktionslust een image publiceert (nu alleen `1.7.2-rc-1`).

### 2026-10-16 - Upgrade naar 1.7.2 via eigen image Gabbaya (LIVE)

**Image:** `ghcr.io/torreirow/gabbaya` (repo https://github.com/torreirow/gabbaya), afgesplitst van
funktionslust/invoiceplane-docker (sinds feb. stil, geen 1.7.2-image). Bouwt de officiële release-zip
(`UPSTREAM_VERSION` + `UPSTREAM_SHA256`) en past `patches/series` toe. Wekelijkse CI opent een PR bij
een nieuwe InvoicePlane-release; een patch die upstream is opgenomen laat de build falen → verwijderen.

**Patches (1.7.2):**
- `0001-session-empty-save-path`: lege `SESS_SAVE_PATH` uit `ipconfig.php.example` breekt sessies →
  setup/login blijft hangen (InvoicePlane#1690). Backport van #1699 (opgelost in 1.8).
- `0003-email-template-preview` (2026-10-16): preview van mailtemplates rendert de mail i.p.v. de
  HTML-bron (backport upstream f20b9c9e, InvoicePlane#1432; opgelost in 1.8). `srcdoc` in een
  `sandbox=""`-iframe, ook in de twee verzendschermen. Browser-cache legen als de oude preview blijft.
- `0002-custom-public-templates`: eigen web-templates onbruikbaar (pad-check negeert
  `CUSTOM_TEMPLATES_FOLDER` → 500; eigen bestanden zonder `$this`). Nog niet upstream gemeld.
- Entrypoint installeert `.htaccess` bij `REMOVE_INDEXPHP=true` → `ExecStartPost`-workaround weg.

**Nieuwe indeling op malandro:**

| Pad                                   | In container         | Wat                                        |
| ------------------------------------- | -------------------- | ------------------------------------------ |
| `/data/external/invoiceplane-docker`  | `uploads/`           | uploads, logo's, css, favicon (ongewijzigd) |
| `/data/external/invoiceplane-config`  | `/config`            | `ipconfig.php` (blijvend)                   |
| `/data/external/invoiceplane-templates` | `/custom-templates` (ro) | `WereldVanBegrip` (pdf) en `WereldVanBegrip_Web` (web), factuur + offerte |

Templates staan in de `CUSTOM_*`-allowlist (Nix `environment`, geen geheim). Sinds 1.7.2 scant
InvoicePlane de templatemap niet meer (RCE-fix); de oude overmounts van `views/*_templates` zijn weg.
Instellingen + mailtemplates 1 en 3 gebruiken `WereldVanBegrip`; herinnering houdt `InvoicePlane - overdue`.

**Belangrijk:** `SETUP_COMPLETED` en `ENCRYPTION_KEY` komen uit het agenix-env-file en gaan vóór
`ipconfig.php`. mPDF haalt CSS op via de publieke `IP_URL` → `/assets/` moet publiek blijven in nginx.

**Upgrade-procedure (volgende keer):**
1. Gabbaya-PR van de wekelijkse check mergen → nieuwe digest uit ghcr.
2. Testen tegen een DB-kopie (testcontainer op een losse poort, SMTP in de kopie onschadelijk maken).
3. Backup (DB-dump + `invoiceplane-docker`), digest in `modules/invoiceplane-docker.nix`.
4. Tijdelijk `DISABLE_SETUP = "false"` en `SETUP_COMPLETED = "false"` in `environment`, rebuild, `/setup` doorlopen, terugzetten, rebuild. (Beide `true` = geen "Security Warning" in 1.7.2.)

**Terugdraaien:** digest terug naar `funktionslust/invoiceplane@sha256:8fa4726e…` (1.7.1) **én** de DB
terugzetten uit `/data/external/invoiceplane-backup-20261016/invoiceplane-db-pre-1.7.2.sql` (schema is nu 043).

### 2026-10-16 - Single sign-on (OIDC) via Authelia (Gabbaya patch 0004)

**Doel:** één Authelia-login (wachtwoord + 2FA) en direct in InvoicePlane, zonder tweede login.

**Flow:**
```
browser → invoices.wereldvanbegrip.nl → nginx forward-auth → Authelia (1× inloggen)
        → /sessions/login → (auto-redirect) /sessions/oidc_login
        → auth.wereldvanbegrip.nl/api/oidc/authorization (sessie bestaat, consent pre-configured)
        → /sessions/oidc_callback → dashboard
```

**Onderdelen:**
- Code: Gabbaya patch `0004-oidc-sso` (jumbojett/openid-connect-php, PKCE S256), herbouwd uit
  InvoicePlane#1448; fork-branch `feature/oidc-sso`. Migratie `043a_1.7.2.sql`
  (`user_password` nullable, `user_auth_provider`, unieke `user_oidc_sub`).
- Authelia: client `invoiceplane` + beleid `invoiceplane` (groep invoiceplane, two_factor) in
  `modules/authelia.nix`; alleen de argon2-hash van het secret staat daar.
- Secret: `secrets/invoiceplane-oidc.age` (`OIDC_CLIENT_SECRET=…`), als tweede `--env-file`.
- Env (Nix `environment`): `OIDC_ENABLED`, `OIDC_PROVIDER_URL=https://auth.wereldvanbegrip.nl`,
  `OIDC_CLIENT_ID=invoiceplane`. De issuer moet exact gelijk zijn aan `OIDC_PROVIDER_URL`.
- Instellingen (DB, Instellingen → Single sign-on): `oidc_auto_redirect_login=1`,
  `oidc_allow_local_login=1`, `oidc_auto_create_users=0`, `oidc_require_email_verified=1`.

**Account-koppeling:** eerst op `user_oidc_sub`; anders één keer op geverifieerde e-mail die precies
één account matcht. E-mail in Authelia moet dus gelijk zijn aan die in InvoicePlane:
`wouter@toorren.net`, `maaike@wereldvanbegrip.nl`. Nieuwe gebruiker: eerst in Authelia (groep
`invoiceplane`), dan in InvoicePlane met hetzelfde e-mailadres aanmaken.

**Noodroutes:**
1. OIDC faalt (secret, client, claim): `https://invoices.wereldvanbegrip.nl/sessions/login?local=1`
   → lokaal wachtwoord (bewaar het wachtwoord van `wouter@toorren.net`). Na een SSO-fout wordt
   niet opnieuw doorgestuurd; uitloggen gaat ook naar `?local=1`.
2. Authelia helemaal plat: forward-auth blokkeert óók `?local=1`. Dan buiten nginx om:
   `ssh -L 8092:127.0.0.1:8092 malandro` → `http://localhost:8092/sessions/login?local=1`.
   Klantlinks (`/guest/`) werken gewoon door (staan buiten Authelia).

**Tests:** `tests/oidc-e2e/run.sh` in Gabbaya (18 scenario's tegen een mock-OIDC-provider, ook in CI).
