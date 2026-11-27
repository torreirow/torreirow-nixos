# Proposal

## Why

De CV-site is publiek bereikbaar. `robots.txt` vraagt crawlers te stoppen, maar
dwingt niets af: AI-crawlers, scrapers en niet-browserclients kunnen de HTML
gewoon lezen. Alleen de PDF's zijn al beschermd met een Cap-proof-of-work. De
site moet daarom op netwerkniveau alleen toegankelijk worden voor bezoekers die
een browsercontrole kunnen uitvoeren.

## What Changes

- Voeg een **Anubis**-instantie toe (uit nixpkgs) vóór de CV-vhost.
- Anubis daagt **elke** request uit met een proof-of-work; na succes krijgt de
  bezoeker een ondertekende cookie.
- Zet **Open Graph-passthrough** aan, zodat linkpreviews titel en beschrijving
  kunnen lezen zonder de pagina-inhoud te krijgen.
- Splits de nginx-opzet:
  - publieke vhost: TLS/ACME, proxy naar Anubis;
  - lokale backend-vhost op `127.0.0.1:8080`: statische site, `/download` en de
    bestaande 404 voor directe PDF-toegang.
- Behoud de bestaande **Cap-broker** voor PDF-downloads als tweede laag.
- Geef interne health checks een local-only uitzondering, buiten Anubis om.
- Behoud `robots.txt`, noindex en de bestaande redirect van `cv-wouter.toorren.net`.

## Capabilities

### New Capabilities

- `wouter-resume-browser-gate`: netwerktoegang tot de CV-site vereist een
  succesvolle browser/proof-of-work-controle; niet-browsers en AI-crawlers
  worden geweigerd, met behoud van de Cap-beveiliging voor PDF's.

### Modified Capabilities

Geen. De bestaande `wouter-resume-hosting`-specificatie is nog niet naar de
hoofdspecs gesynchroniseerd; deze change introduceert daarom een losse,
duurzame capability voor de toegangscontrole.

## Impact

- `modules/nginx-wouter-resume.nix` en `hosts/malandro/configuration.nix`.
- Nieuwe NixOS-service `services.anubis.instances.cv`.
- Nginx: publieke vhost, lokale backend-vhost, socketrechten voor `nginx`.
- Geen wijzigingen aan de CV-content of Hugo-build.
- Linkpreviews blijven beperkt tot Open Graph-metadata.
- De site is niet meer bereikbaar als Anubis stopt; systemd-restart en monitoring
  zijn nodig.
