# Proposal

## Why

Er is nu geen enkel zicht op bezoek aan de publieke websites: niet hoeveel, niet welke pagina's,
niet vanuit welk land of welke stad. Dat geldt voor de sites op malandro én voor de sites op
Cloudflare Pages. Een zelf gehoste, cookieloze teller geeft dat inzicht zonder persoonsgegevens
te bewaren en zonder cookiebanner.

## What Changes

- Umami (NixOS-module `services.umami`, PostgreSQL op malandro) draait op `stats.toorren.net`.
- Gemeten worden: paginaweergaven, bezoekers en sessies (anoniem), verwijzers, apparaat/browser,
  **land en stad** (GeoLite2-City, meegeleverd door nixpkgs). IP-adressen worden niet bewaard.
- Het tracker-script en de meld-URL zijn publiek; het dashboard staat achter Authelia.
- Script en meld-URL krijgen een neutrale naam, zodat adblockers ze minder vaak tegenhouden.
- Op malandro voegt nginx het script automatisch in bij deze sites: `toorren.net`,
  `wereldvanbegrip.nl`, `cckafe.com`,
  `cv-jolijn.toorren.net`, `boaz.toorren.net`, `eghupload.toorren.net`.
- Op Cloudflare Pages krijgen deze sites het script in hun broncode: `noraly.toorren.net`,
  `devos.dutchyland.net`, `recepten.toorren.net`, `www.stichtingwittevelden.nl`.
- Bewust niet gemeten: apps met eigen login (Grafana, Home Assistant, Nextcloud, Vikunja,
  Erugo, Wallos, chhoto-url), inlog- en API-diensten (Authelia/Pocket-ID, Cap, formrelay,
  mailer), Castopod (meet zelf), `onzeovereenkomst.wereldvanbegrip.nl` (DocuSeal: app met
  vertrouwelijke documenten; de strikte CSP blokkeert het script terecht), `stwvwiki`, `opsknight`, `adresses`, en alles achter Authelia.
  Redirect-only vhosts (zoals `stichtingwittevelden.nl` → `www.`) leveren geen pagina en dus
  geen meting.

## Capabilities

### New Capabilities

- `website-analytics`: anonieme bezoekmeting voor de publieke websites op malandro en Cloudflare
  Pages: wat er gemeten wordt (incl. land/stad), wat bewust niet (IP-adressen, personen), welke
  sites wel en niet meedoen, en wie het dashboard mag zien.

### Modified Capabilities

(geen)

## Impact

- Nieuwe module `modules/umami.nix` (dienst, nginx-vhost `stats.toorren.net`, Authelia voor het
  dashboard) en een agenix-secret voor `APP_SECRET`.
- `modules/nginx.nix` of de betreffende site-modules: script-injectie per vhost.
- PostgreSQL op malandro: nieuwe database/gebruiker `umami`; meegenomen in de bestaande
  rustic-backup (pg_dumpall).
- `modules/status-page.nix`: `umami` in de lijst native diensten.
- Vier Cloudflare-repo's (niet op deze machine aanwezig): één `<script>`-regel per site.
- Docs: nieuw `docs/umami.md` + indexregel in `CLAUDE.md`.
