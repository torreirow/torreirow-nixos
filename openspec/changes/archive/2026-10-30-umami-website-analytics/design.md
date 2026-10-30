# Design

## Context

Zie proposal.md voor het waarom en de sitelijst; `specs/website-analytics/spec.md` voor het
gedrag. Relevante feiten (verkend op 30-10-2026):

- nixpkgs heeft `services.umami` (Umami 3.4.0). Het pakket levert GeoLite2-City mee
  (`GEOLITE_DB_PATH`), dus land én stad werken zonder MaxMind-account.
- PostgreSQL draait al op malandro (`modules/postgres.nix`); rustic-backup dumpt met
  `pg_dumpall`, dus een nieuwe database valt automatisch in de backup.
- nginx draait met `recommendedProxySettings` (zet `X-Real-IP`/`X-Forwarded-For`).
- Alle sites serveren gzip. Van de malandro-sites stuurt alleen DocuSeal
  (`onzeovereenkomst`) een CSP, met een nonce per verzoek en alleen op GET (een HEAD-check mist
  hem); die site valt daarom buiten de meting. Op Cloudflare heeft
  alleen `www.stichtingwittevelden.nl` een CSP: `script-src 'self' 'unsafe-inline'` en
  `connect-src 'self'`. Die blokkeert een extern script én het melden.
- De vier Cloudflare-repo's (`noraly-cv`, `dailydevos`, `toorren-recepten`, `stwv-development`
  op Pages) staan niet op malandro.

## Goals / Non-Goals

**Goals:**
- Eén dashboard voor alle 10 sites, met land en stad.
- Malandro-sites meten zonder hun broncode aan te passen.

**Non-Goals:**
- Personen of organisaties herkennen, IP-adressen bewaren.
- Server-side meting uit nginx-logs (GoAccess e.d.); bezoekers zonder JavaScript worden niet
  geteld.
- Cloudflare Web Analytics als tweede bron.
- Meten van apps, inlogdiensten, API's of sites achter Authelia.

## Decisions

### 1. Umami via de NixOS-module, eigen PostgreSQL-database
`services.umami` met een database `umami` en gebruiker `umami` via peer-auth op de lokale
PostgreSQL (`ensureDatabases`/`ensureUsers`, zoals Vikunja en InvoicePlane). `APP_SECRET` komt
uit agenix (`secrets/umami-app-secret.age`, alleen root leesbaar; de module geeft hem via
`LoadCredential` door aan de DynamicUser). Umami luistert alleen op
127.0.0.1 op een vrije poort.
*Alternatief:* Docker-image van Umami. Afgewezen: de NixOS-module bestaat, past bij de rest
en geeft automatische updates via nixpkgs.

### 2. Eén vhost `stats.toorren.net`, gesplitst in publiek en afgeschermd
- Publiek: het hernoemde script en het hernoemde meldadres (Decision 3), plus wat het script
  nodig heeft. Geen Authelia, wel `limit_req` tegen overspoelen.
- Afgeschermd: al het andere (het dashboard) via Authelia forward-auth, volgens het patroon van
  `cockpit.nix`; toegang voor de groep `monitoring` (`docs/authelia-rbac.md`). Umami's eigen
  login blijft daarachter bestaan (admin-wachtwoord direct na installatie wijzigen).
*Alternatief:* alleen Umami's eigen login. Afgewezen: de rest van de beheer-UI's zit achter
Authelia; één toegangsmodel is overzichtelijker en beschermt tegen login-brute-force.

### 3. Neutrale namen tegen adblockers
`TRACKER_SCRIPT_NAME` wordt een neutrale naam (bijv. `s.js`) en `COLLECT_API_ENDPOINT` een
neutraal pad (bijv. `/api/e`). Geen "umami", "analytics", "stats" of "track" in de URL's van
script en meldadres. Het domein `stats.` zelf kan op sommige filterlijsten staan; dat accepteren
we (eigen subdomein, geen gedeelde blocklist-hit zoals `*.umami.is`).

### 4. Locatie op het echte bezoekers-IP
Umami krijgt `CLIENT_IP_HEADER=x-real-ip`. nginx zet `X-Real-IP` op `$remote_addr`, en omdat
`stats.toorren.net` niet achter Cloudflare-proxy staat (A-record direct naar malandro), is dat
het IP van de bezoeker, ook voor meldingen vanaf de Cloudflare-sites (de browser praat direct
met `stats.toorren.net`). Umami gebruikt het IP alleen voor de GeoIP-lookup en de anonieme
sessie-hash; het slaat het niet op.

### 5. Script-injectie op malandro met `sub_filter`
Per gemeten vhost voegt nginx vóór `</body>` het script in (niet `</head>`: de geminificeerde
Hugo-pagina van toorren.net laat die optionele tag weg; `</body>` hebben alle zeven):
`<script defer src="https://stats.toorren.net/s.js" data-website-id="<id>"></script>`.
Dat wordt een kleine Nix-helper (bijv. `umamiTrack = id: { ... }`) die op een location wordt
gezet. Omdat sub_filter niet werkt op gecomprimeerde upstream-antwoorden, zet de helper bij
proxied sites `proxy_set_header Accept-Encoding ""`; nginx comprimeert daarna zelf weer naar de
browser. Statische sites (root) werken direct.
De site-ID's zijn niet geheim (ze staan in elke pagina) en komen als vaste waarden in de Nix-config.
*Alternatief:* het script in elke site-repo zetten. Afgewezen voor malandro: zeven repo's/apps
aanpassen, en eghupload/toorren.net zijn deels gegenereerd.

### 6. Cloudflare-sites: script in de broncode
Per Cloudflare-repo één regel in de gedeelde `<head>`-template. Voor
`www.stichtingwittevelden.nl` moet ook de CSP (waarschijnlijk in `_headers` van Pages) worden
uitgebreid: `script-src` en `connect-src` met `https://stats.toorren.net`.
*Alternatief:* een Cloudflare Worker die het script met HTMLRewriter invoegt. Afgewezen: extra
infrastructuur buiten de repo's, en de CSP moet toch aangepast.

### 7. Bewaartermijn
Umami bewaart standaard alles. We beginnen zonder opschonen; bij groei kan later een
periodieke opschoning (bijv. ouder dan 2 jaar) worden toegevoegd. Dat verandert de spec niet.

## Risks / Trade-offs

- [Adblockers en privacy-browsers tellen niet mee] → neutrale namen (Decision 3); de cijfers
  blijven een ondergrens. Dat wordt in `docs/umami.md` vermeld.
- [sub_filter breekt een site] → alleen `</head>` wordt vervangen, en alleen in `text/html`;
  per site testen dat de pagina gelijk blijft op het script na.
- [GeoLite2-stad is grof] → stad is "indien bepaalbaar"; mobiele netwerken tonen vaak de stad
  van de provider. Land is betrouwbaar.
- [Meetdienst plat] → `defer`-script; meldfouten zijn onzichtbaar voor de bezoeker.
- [Spam-meldingen naar het publieke meldadres] → onbekende site-ID's weigert Umami; `limit_req`
  op het meldadres; het dashboard toont alleen de 10 sites.

## Migration Plan

1. `modules/umami.nix` + secret + PostgreSQL, rebuild; admin-wachtwoord wijzigen; de websites
   aanmaken in het dashboard en de site-ID's noteren.
2. sub_filter-helper op de 6 malandro-vhosts, rebuild, per site controleren.
3. Per Cloudflare-repo de scriptregel (en bij stichtingwittevelden de CSP), deploy via Pages.

Terugdraaien: helper van de vhosts halen en rebuild; de Umami-dienst kan los blijven draaien of
uit; Cloudflare-regels terugdraaien in de repo's.
