# Proposal

## Why

De fotodienst `cckafe-photos` kopieert de previews uit Immich naar
`/var/lib/cckafe-photos/<slug>/` en nginx serveert die kopieën. Dat was nodig toen
Immich's `preview` 1920px JPEG van ~500 kB was: lokaal verkleinen gaf 150 kB.

Sinds `modules/immich.nix` `image.preview` op WebP met een korte zijde van 800 zet, is
Immich's preview ~155 kB — dezelfde omvang als de kopie. Daarmee is de kopie overbodig:

- er staat een tweede exemplaar van elke foto op schijf (37 MB bij acht meet-ups van
  dertig foto's);
- een verdwenen of geleegd album laat de oude map staan, dus de site serveert foto's die
  in Immich niet meer bestaan (nu zichtbaar bij `assen-2026-08-13`);
- de dienst moet downloaden, verkleinen en opruimen, en `magick` meelopen.

## What Changes

- `fetch.sh` haalt per album alleen nog metadata op en schrijft `manifest.json` met per foto
  `id`, `width`, `height`, `v` (wijzigingstijd) en `source`. Geen downloads, geen
  verkleinen, geen `imagemagick` meer.
- Nginx serveert de foto's op `/immich/<asset-id>.webp` als proxy naar Immich
  (`/api/assets/<id>/thumbnail?size=preview`), met de API-sleutel in een header uit een
  age-secret. `/photos/<slug>/manifest.json` blijft een statisch bestand.
- De bestandsnaam van het age-secret met de API-sleutel blijft ongewijzigd; er komt een
  tweede secret bij met het kant-en-klare `proxy_set_header`-snippet, zodat de tokenwaarde
  nooit in de nix-store of in de HTML belandt (zelfde patroon als `linny-mcp`).
- De afmetingen in het manifest worden berekend uit de verhouding van het origineel en de
  korte zijde van 800 (`fit: outside`), niet uit een gedownload bestand.
- De test dekt het nieuwe gedrag: manifest met asset-id's, geen fotobestanden, en een
  verdwenen album laat het vorige manifest staan.
- `docs/cckafe-photos.md` beschrijft de proxy in plaats van de kopieën.

Dit is een **BREAKING** wijziging van de URL-vorm: de website moet de foto-URL uit `id`
bouwen (`/immich/<id>.webp`) in plaats van uit `file`. Beide kanten moeten samen live.

## Capabilities

### New Capabilities

- `cckafe-photos`: de keten van Immich-album naar zichtbare galerij op cckafe.com — het
  manifest dat de dienst schrijft, de proxy die nginx aanbiedt, en de eis dat de albums
  privé blijven.

### Modified Capabilities

Geen. `immich-photos` gaat over de Immich-installatie zelf en verandert niet.

## Impact

**torreirow-nixos**

- `modules/cckafe-photos/fetch.sh`: download- en verkleinstap eruit, manifest met id's.
- `modules/cckafe-photos/package.nix`: `imagemagick` uit `runtimeInputs`.
- `modules/cckafe-photos/test.nix`, `stub_server.py`: tests op het nieuwe gedrag.
- `modules/cckafe.nix`: `/photos/` blijft de alias voor manifesten; `/immich/` wordt een
  proxy-locatie.
- `secrets/immich-cckafe-photos-nginx-key.age` + `secrets/secrets.nix`.
- `docs/cckafe-photos.md`.

**cckafe-website** (buiten deze repo, taak 6.5 van `meetup-photos-from-immich`)

- `assets/js/app.js`: foto-URL uit `id`, met `?v=` als cache-buster.

**Afhankelijkheden**

- Immich op `127.0.0.1:2283`, bereikbaar vanaf malandro.
- De galerij is vanaf nu afhankelijk van een draaiende Immich; de rest van de site niet.
