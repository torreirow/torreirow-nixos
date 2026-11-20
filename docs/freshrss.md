# FreshRSS (feeds.toorren.net)

CVE-/security-feedreader op malandro. Native NixOS-module (`services.freshrss`), php-fpm +
SQLite, geen Docker. Bron: `modules/freshrss.nix`, feedlijst in
`modules/freshrss-security-feeds.opml`.

## Toegang

- URL: <https://feeds.toorren.net>
- Auth: **Authelia forward-auth** (2FA, groep `personal-wouter`) vóór de web-UI. FreshRSS
  staat op `http_auth`, dus na Authelia ben je direct ingelogd als `wouter` — geen tweede
  wachtwoord.
- De **API** (`/api/`, `/f.php`) staat bewust buiten Authelia; die gebruikt het
  API-wachtwoord, zodat Readrops blijft werken.
- FreshRSS-wachtwoord: agenix-secret `secrets/freshrss-password.age`; op de host te lezen met
  `sudo cat /run/keys/wouter/freshrss-password`. Het is nog alleen nodig als je terugvalt op
  form-auth; de gebruiker is ermee aangemaakt. De gebruiker `freshrss` zit in de groep `keys`,
  anders kan `freshrss-config` het secret niet lezen.
- API: Google Reader-API staat aan (`services.freshrss.api.enable`). Het API-wachtwoord is
  per gebruiker gezet met `cli/update-user.php --api-password` en staat alleen gehasht in
  `/var/lib/freshrss/users/wouter/config.php`. Opnieuw zetten:

  ```sh
  CLI=$(systemctl show freshrss-updater -p ExecStart --value | grep -o '/nix/store/[^ ]*/cli')
  sudo -u freshrss env DATA_PATH=/var/lib/freshrss "$CLI/update-user.php" \
    --user wouter --api-password 'nieuw-api-wachtwoord'
  ```

Let op: `http_auth_auto_register` staat aan. Alleen leden van `personal-wouter` komen door
Authelia heen, dus in de praktijk is `wouter` de enige die een account kan krijgen.

## Authelia / nginx

- `modules/authelia.nix`: regel voor `feeds.toorren.net` met `two_factor` en
  `subject = [ "group:personal-wouter" ]`.
- `modules/freshrss.nix`: `auth_request /authelia` op `/` en de PHP-location; de
  `^~ /api/`- en `= /f.php`-locations slaan Authelia over.
- Authelia's `Remote-User` gaat als `fastcgi_param REMOTE_USER` naar php-fpm. Inkomende
  `Remote-User`/`X-WebAuth-User`-headers worden expliciet leeggemaakt: FreshRSS vertrouwt die
  anders omdat php-fpm nginx als `127.0.0.1` ziet (`trusted_sources`).
- Zonder Authelia-sessie geeft de UI een 302 naar `https://auth.toorren.net/?rd=...`.
- FreshRSS' eigen OIDC-client bestaat niet op nginx (dat is Apache `mod_auth_openidc`); deze
  forward-auth is de nginx-variant.

## Readrops / Google Reader-API

| Veld | Waarde |
|---|---|
| Server-URL | `https://feeds.toorren.net` |
| API-pad | `/api/greader.php` |
| Gebruiker | `wouter` |
| Wachtwoord | API-wachtwoord (niet het login-wachtwoord) |

De ClientLogin-endpoint is `POST /api/greader.php/accounts/ClientLogin` met `Email=wouter`
en `Passwd=<api-wachtwoord>`; daarna `Authorization: GoogleLogin auth=<Auth>` op
`/reader/api/0/...`.

## Verversen en retentie

- `freshrss-updater.timer` draait elke 5 minuten `app/actualize_script.php`.
- `ttl_default` staat op **900 s (15 min)**, dus elk kanaal ververst binnen 15–30 minuten.
- De hoofdstroom staat op `default_state = 2` (alleen ongelezen).

## Feeds

Categorieën: **Security – Bronnen**, **Security – Researchers**, **Security – Aanvulling**.

| Feed | URL | Status |
|---|---|---|
| NCSC-NL beveiligingsadviezen | `https://advisories.ncsc.nl/rss/advisories` | werkt |
| AWS Security Bulletins | `https://aws.amazon.com/security/security-bulletins/rss/feed/` | werkt |
| CISA Advisories (incl. KEV) | `https://www.cisa.gov/cybersecurity-advisories/all.xml` | werkt; vervangt KEV-JSON |
| NixOS Announcements (incl. security) | `https://discourse.nixos.org/c/announcements/8.rss` | werkt; NixOS heeft geen aparte security-feed |
| Debian DSA | `https://www.debian.org/security/dsa` | werkt (RDF/RSS) |
| Ubuntu USN | `https://ubuntu.com/security/notices/rss.xml` | werkt |
| Wiz Research (blog) | `https://www.wiz.io/feed/rss.xml` | werkt |
| Wiz (Mastodon) | `https://infosec.exchange/@wiz.rss` | werkt |
| Rapid7 (blog) | `https://www.rapid7.com/rss.xml` | werkt |
| Rapid7 (Mastodon) | `https://infosec.exchange/@rapid7.rss` | werkt, maar account is sinds feb 2023 inactief |
| nginx releases (GitHub) | `https://github.com/nginx/nginx/releases.atom` | werkt; vervangt nginx-announce |
| oss-sec (seclists.org) | `https://seclists.org/rss/oss-sec.rss` | werkt; vervangt de mailinglijst |

Geen werkende feed:

- **F5 Security Advisories** — de oude RSS (`support.f5.com/csp/rss/security`) leidt naar de
  MyF5-login. Een custom RSS maken kan alleen ingelogd via MyF5 (K9957); de URL is vaak aan
  een account gebonden. Alternatief: F5 Security Announcements per e-mail, of de CISA-feed
  hierboven.
- **CISA KEV** — alleen JSON/CSV, geen RSS. De CISA Advisories-feed bevat de
  "CISA Adds … Known Exploited Vulnerabilities"-berichten.
- **nginx-announce** — mailinglijst zonder feed; gebruik de GitHub-releases-feed.
- **oss-security** — mailinglijst zonder feed; gebruik de seclists-spiegel.
- **NixOS security** — geen aparte security-categorie/feed; de Announcements-feed bevat de
  security advisories. Een stream op `nixos OR security` filtert ze eruit.

## Feed of stream toevoegen

- Feed: FreshRSS → **Abonnementen beheren** → *Nieuwe feed* (of importeer een OPML via
  **Abonnementen beheren → Importeren**). Categorieën zijn gewone FreshRSS-categorieën.
- Stream (opgeslagen zoekopdracht): zoek in de hoofdstroom, klik op het bookmark-icoon →
  **Deze zoekopdracht opslaan**, of via **Configuratie → Streams**.
- Bestaande streams: **Mijn stack**, **Kritiek**, **NGINX**. Ze staan in
  `/var/lib/freshrss/users/wouter/config.php` onder `queries`; opnieuw toepassen kan met
  `scripts/freshrss-queries.php` (als freshrss, met `DATA_PATH`, `FRSS_CLI` en `FRSS_USER`).

## OPML (CLI-import)

```sh
CLI=$(systemctl show freshrss-updater -p ExecStart --value | grep -o '/nix/store/[^ ]*/cli')
sudo -u freshrss env DATA_PATH=/var/lib/freshrss "$CLI/import-for-user.php" \
  --user wouter --filename /pad/naar/security-feeds.opml
```

## nginx

- `modules/nginx.nix` pint nginx op **1.30.7** (patchrelease met de fix voor
  CVE-2026-123633/123007); weghalen zodra de nixpkgs-pin ≥ 1.30.7 levert.
- HTTP/2 staat op malandro **uit** voor alle vhosts (`modules/nginx-no-http2.nix`). Nieuwe
  vhost toevoegen aan de lijst, anders faalt de build via de assertion.
