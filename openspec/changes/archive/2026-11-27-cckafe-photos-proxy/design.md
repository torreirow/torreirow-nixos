# Design

## Context

`modules/cckafe-photos/` draait als oneshot-service met een timer op malandro. De dienst
leest `/var/www/{,test.}cckafe.com/meetups/index.txt` (TSV: slug en albumnaam), haalt per
album de assets op bij Immich en schreef tot nu toe de previews plus een manifest naar
`/var/lib/cckafe-photos/<slug>/`. Nginx serveerde die map met een `alias` op `/photos/`.

Immich's preview-instelling staat sinds kort op WebP met een korte zijde van 800
(`modules/immich.nix`), dus ~155 kB per foto. De kopie levert daardoor geen gewichtswinst
meer op, wel een tweede exemplaar en een opruimprobleem: een verdwenen album laat de oude
map staan, en de site blijft foto's tonen die niet meer bestaan.

## Goals / Non-Goals

**Goals:**

- Eén bron van waarheid: de foto's staan alleen in Immich.
- De dienst hoeft niets te downloaden of te verkleinen; hij schrijft alleen nog een
  manifest van een paar honderd bytes.
- De albums blijven onbereikbaar zonder API-sleutel; er komt geen share-link.
- Een gewijzigde of vervangen foto is direct zichtbaar, zonder wachttijd op een timer.

**Non-Goals:**

- Geen server-side cache. `proxy_cache` zou de druk wegnemen maar schrijft weer naar schijf,
  net zo veel als de kopieën; dat is een terugvaloptie, geen beginpunt.
- Geen publieke Immich-URL, geen share-links, geen signed URLs.
- De dienst blijft de site niet bouwen; `release.sh` blijft de enige route voor HTML.

## Decisions

### D1 — Nginx proxyt, de dienst schrijft alleen het manifest

**Keuze.** `/immich/<asset-id>.webp` wordt door nginx geproxyt naar
`http://127.0.0.1:2283/api/assets/<asset-id>/thumbnail?size=preview`, met de API-sleutel in
een `x-api-key`-header. De dienst schrijft alleen `/var/lib/cckafe-photos/<slug>/manifest.json`,
dat nginx via de bestaande `alias` op `/photos/` blijft serveren.

**Alternatieven.**

- *Blijven kopiëren* — werkt zonder Immich, maar kost 37 MB bij acht albums, houdt een
  resize-stap in die niets meer doet, en laat verlopen albums staan. Afgewezen.
- *`proxy_cache`* — haalt de piekdruk weg maar schrijft dezelfde bytes naar schijf. Bewust
  bewaard als terugvaloptie, niet als uitgangspunt.
- *Foto's onder `/photos/<id>.webp`* — logischer in de URL, maar `/photos/` is een prefix
  met `^~`, en die wint van elke regex-locatie. Een regex voor asset-id's zou bovendien
  concurreren met de bestaande `~* \.(woff2|png|jpe?g|webp|...)$`, waarvan de volgorde
  afhangt van hoe het nginx-module de locaties rangschikt. Afgewezen: te fragiel.
- *Een aparte vhost of poort voor de proxy* — meer bewegende delen voor hetzelfde resultaat.

**Consequentie.** `/immich/` is een nieuwe publieke prefix met een strikte vorm
(`<uuid>.webp`), zodat er niets anders doorheen kan. Immich wordt een
runtime-afhankelijkheid van de galerij; de rest van de site blijft statisch.

### D2 — Het manifest houdt de volgorde en de afmetingen

Immich levert de assets in zijn eigen volgorde, en de browser heeft afmetingen nodig om
layout-shift te voorkomen. Het manifest is dus geen kopie van de data maar de index:

```json
{ "slug": "ermelo-2026-10-08", "album": "meetup-ermelo-2026-10-08",
  "photos": [ { "id": "b5e38bc5-…", "width": 1200, "height": 800,
                "v": "2026-11-20T18:47:26.900Z", "source": "foto.jpg" } ] }
```

De afmetingen worden berekend uit de verhouding van het origineel en de korte zijde van
800 (`fit: outside`), niet gemeten: er wordt niets gedownload. `v` is de wijzigingstijd van
het asset en dient als cache-buster in de URL, zodat de lange browsercache veilig is.

### D3 — De sleutel als kant-en-klaar nginx-snippet in een age-secret

**Keuze.** Het age-secret bevat geen kale tokenwaarde maar een complete regel
`proxy_set_header x-api-key "…";`, die de proxy-locatie includet. Zelfde patroon als
`modules/linny-mcp.nix`.

**Waarom.** Nix-opties staan wereldleesbaar in de nix-store. Een pad naar een secret is
ongevaarlijk, een tokenwaarde niet. En door het snippet in het secret te zetten hoeft de
waarde nooit door een Nix-string heen.

**Consequentie.** De eigenaar van het bestand moet `nginx` zijn (mode `0400`), zodat de
master het bij het opstarten kan lezen.

## Risks / Trade-offs

- **Immich plat → geen galerij** → de foto-URL's geven een foutstatus; de pagina zelf werkt.
  Bewust geaccepteerd, dit is de prijs voor één bron van waarheid.
- **Piekdruk op de J3455** → elke bezoeker tikt Immich aan. Bij 240 foto's van ~155 kB is
  het gemiddelde verwaarloosbaar; de burst bij een verse meet-up is het punt. `proxy_cache`
  is de terugvaloptie.
- **`/immich/` is een nieuwe publieke prefix** → de locatie accepteert alleen
  `<uuid>.webp`; al het andere geeft 404. Zonder API-sleutel levert Immich 401, en de
  sleutel zit in de header die nginx zet, niet in de URL.
- **Manifest en Immich lopen kort uit elkaar** → maximaal één timerinterval. De foto's zelf
  zijn altijd actueel; alleen de lijst en volgorde lopen achter.
- **Bestaande fotomappen blijven staan** → na de omschakeling moeten de oude `.webp`-bestanden
  wijken, anders serveert de `alias` ze alsnog op `/photos/<slug>/001.webp`.

## Migration Plan

1. Secret toevoegen en `fetch.sh` omschrijven; `nix build .#checks.x86_64-linux.cckafe-photos`
   groen.
2. `nixos-rebuild switch` op malandro; controleren dat `/immich/<id>.webp` een WebP geeft.
3. De website-kant (`app.js`) mee uitrollen; zonder dat vraagt de pagina nog om
   `/photos/<slug>/001.webp`, dat na het opruimen 404 geeft.
4. Oude `.webp`-bestanden onder `/var/lib/cckafe-photos/` verwijderen, zodat alleen
   `manifest.json` overblijft.

**Terugrol:** `app.js` terugzetten en de vorige generatie activeren; de kopieën komen dan
terug bij de volgende run. Wie alleen de proxy terugdraait maar `app.js` laat staan, krijgt
een galerij zonder foto's.
