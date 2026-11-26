# Proposal

## Why

De CV-site in `wouter-cv` wordt al gebouwd en via `release.sh` naar
`malandro:/var/www/cv-wouter` gereleased, maar heeft geen nginx-vhost. Bezoek aan
`wouter-resume.toorren.net` valt daardoor op de `wildcard-placeholder` die met 444
afkapt. De site is dus feitelijk al live-bestand maar publiek onbereikbaar.

## What Changes

- Nieuw NixOS-module `modules/nginx-wouter-resume.nix` met twee virtuele hosts:
  - `wouter-resume.toorren.net` serveert statisch `/var/www/cv-wouter` (HTTPS,
    wildcard-certificaat `toorren.net`, `index.html`, `try_files $uri $uri/ =404`).
  - `cv-wouter.toorren.net` geeft een permanente 301 naar
    `https://wouter-resume.toorren.net` met behoud van pad en query.
- Module importeren in `hosts/malandro/configuration.nix`.
- Beide hostnamen opnemen in `modules/nginx-no-http2.nix`, zodat de bestaande
  assertion blijft slagen en HTTP/2 op dezelfde listener uit blijft.
- `wouter-resume.toorren.net` toevoegen aan `services.aiBlocklist.sites` met
  `noindex = true`, net als `cv-jolijn.toorren.net`: geen zoekindexatie,
  `X-Robots-Tag: noindex, nofollow` en 403 voor AI-crawlers.
- Buiten scope, apart uit te voeren in de `wouter-cv`-repo: `baseURL` wijzigen naar
  `https://wouter-resume.toorren.net/` en opnieuw releasen. Zonder die stap blijft de
  site werken, maar wijzen canonical en sitemap naar de redirectende oude naam.
- Buiten scope: Umami-bezoekmeting; daarvoor is eerst een website-ID uit het
  dashboard nodig.

## Capabilities

### New Capabilities

- `wouter-resume-hosting`: publieke, niet-indexeerbare statische hosting van de
  persoonlijke CV-site op `wouter-resume.toorren.net`, met een permanente redirect
  vanaf de oude naam `cv-wouter.toorren.net`.

### Modified Capabilities

<!-- Geen: ai-crawler-blocklist is generiek en verandert niet van gedrag; dit is
     alleen een nieuwe site in de bestaande configuratie. -->

## Impact

- Nieuw: `modules/nginx-wouter-resume.nix`
- Gewijzigd: `hosts/malandro/configuration.nix` (import en `aiBlocklist.sites`)
- Gewijzigd: `modules/nginx-no-http2.nix` (vhostlijst)
- Server: bestaande webroot `/var/www/cv-wouter` blijft ongewijzigd; `release.sh`
  in `wouter-cv` blijft naar dat pad deployen.
- Geen nieuwe poorten, certificaten of secrets: de bestaande wildcard-DNS en het
  certificaat `*.toorren.net` dekken beide namen.
