# Proposal

## Why

FreshRSS levert inmiddels een brede stroom security-advisories, maar de lezer kan niet zien welke
CVE's daadwerkelijk gelden voor de systemen die in gebruik zijn. Handmatig vergelijken kost tijd,
geeft ruis en leidt tot zowel gemiste kwetsbaarheden als onterechte paniek. Daarom is een
dashboard nodig dat de gedeclareerde systemen en pakketversies afzet tegen de advisories en alleen
toepasselijke CVE's toont.

## What Changes

- Nieuw NixOS-onderdeel `vuln-radar`: een lokale Python-service die per systeem en package
  vaststelt of een CVE van toepassing is.
- Inventaris via een Nix-optie voor eigen hosts en een JSON-bestand voor externe of gemengde
  systemen. Eén host kan packages uit meerdere bronnen hebben: `dpkg`, `nix` en `upstream`.
- Matching op basis van vaste versies: Ubuntu CVE/USN-API, Debian Security Tracker, NVD,
  CISA KEV, vendor-changelogs (PHP/nginx/Apache) en `vulnix` voor Nix-packages. Alleen
  `installed < fixed` verschijnt als treffer.
- HTML-dashboard per systeem/package met severity, CVE, fixed version, bron en link. Daarnaast
  een machine-leesbaar `/vulns.json`.
- Toegang via `https://vulns.toorren.net` achter Authelia; de service luistert alleen op
  `127.0.0.1`.
- Vulnerability-data wordt gecachet; FreshRSS blijft de discovery-/contextlaag en wordt niet
  gewijzigd.
- De bestaande `vulnix-json`-service wordt gerepareerd, zodat NixOS-packages daadwerkelijk
  meegenomen kunnen worden.
- Seed met de testassets: upstream (nginx 1.30.7, PHP 8.3.36) en Debian trixie met Nix-packages
  (Apache 2.4.67, PHP 8.3.37, kernel 6.12.74-2).

## Capabilities

### New Capabilities

- `vuln-radar`: inventaris van systemen en pakketversies, versiebewuste CVE-matching, en een
  geauthenticeerd dashboard dat alleen toepasselijke kwetsbaarheden toont.

### Modified Capabilities

Geen. `status-dashboard` blijft een aparte capability; `authelia-access-control` verandert qua
eisen niet, ook al krijgt de nieuwe vhost een eigen toegangsregel.

## Impact

- Nieuwe `modules/vuln-radar.nix` en `modules/vuln-radar.py`.
- Nieuwe vhost in `modules/authelia.nix` en `hosts/malandro/configuration.nix`.
- `PORTS.md` (poort 9101), `docs/vuln-radar.md` en de `CLAUDE.md`-index.
- Read-only toegang tot `/var/lib/freshrss/users/wouter/db.sqlite`.
- Uitgaande HTTP-verzoeken naar Ubuntu, Debian, NVD, CISA en vendor-sites; resultaten worden
  lokaal gecachet.
- Geen wijziging aan de FreshRSS-feeds, -filters of -database.
