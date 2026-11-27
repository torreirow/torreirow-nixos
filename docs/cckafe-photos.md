# Meet-upfoto's (cckafe.com)

De foto's van een meet-up staan in een album bij Immich en verschijnen automatisch op de
detailpagina van die meet-up. De albums zijn **niet publiek**: de site haalt ze op met een
API-sleutel, er bestaat geen share-link en dus geen openbare Immich-URL die naar een
meet-upalbum wijst.

```
app (telefoon) --> Immich album "meetup-<slug>"
                          |
                          |  GET /api/albums + /api/search/metadata (API-sleutel)
                          v
              cckafe-photos.service (malandro, elke 15 min)
                          |
                          |  schrijft alleen manifest.json (asset-id's, afmetingen)
                          v
              /var/lib/cckafe-photos/<slug>/manifest.json   (niet in de webroot!)
                          |
                          |  nginx alias  /photos/  ->  die map
                          v
              cckafe.com/photos/<slug>/manifest.json
                          ^
                          |  app.js haalt het manifest op en bouwt de <img>-tags
              /meetups/<slug>/  (detailpagina, container in de HTML)

              cckafe.com/immich/<asset-id>.webp
                          ^
                          |  nginx proxy + API-sleutel uit een age-secret
                          |
                        Immich  /api/assets/<id>/thumbnail?size=preview
```

| Onderdeel | Waarde |
|---|---|
| Code | `modules/cckafe-photos/` (`default.nix`, `fetch.sh`, `package.nix`) |
| Host | malandro (`cckafe-photos.service` + `.timer`) |
| Sleutel | `secrets/immich-cckafe-photos-key.age` (dienst) en `secrets/immich-cckafe-photos-nginx-key.age` (proxy) |
| Op schijf | `/var/lib/cckafe-photos/<slug>/manifest.json` (~350 B per album) |
| Manifest-URL | `https://cckafe.com/photos/<slug>/manifest.json` (nginx alias) |
| Foto-URL | `https://cckafe.com/immich/<asset-id>.webp` (nginx proxy naar Immich) |
| Lijst met albums | `/var/www/{,test.}cckafe.com/meetups/index.txt` (TSV, via HTTP geblokkeerd) |

## Waarom de manifesten buiten de webroot staan

`release.sh` doet `rsync -a --delete` over `/var/www/cckafe.com`. Alles wat de fotodienst
daar neerzet zou bij elke release verdwijnen. De manifesten staan daarom in `/var/lib` en
nginx serveert ze met een `alias` op `/photos/`.

## Een meet-up voorzien van foto's

1. Maak in de Immich-app een album met de naam `meetup-<slug>`, bijvoorbeeld
   `meetup-assen-2027-03-11`. De slug is de mapnaam van de meet-up in
   `content/meetups/`, en bevat het jaar zodat albums per jaar gescheiden blijven.
2. Zet dezelfde naam in de front matter van de meet-up:

   ```yaml
   photos:
     album: meetup-assen-2027-03-11
   ```

3. Foto's uploaden naar dat album (de app doet dat automatisch als je het album deelt).
4. De timer haalt ze op binnen 15 minuten. Direct nodig:

   ```bash
   ssh malandro 'sudo systemctl start cckafe-photos'
   ```

5. Ververs de pagina. De galerij laadt in de browser uit
   `/photos/<slug>/manifest.json`; een release is **niet** nodig.

De Hugo-build schrijft alleen een verborgen container met de slug. `app.js` haalt het
manifest op (`cache: 'no-cache'`, dus nginx antwoordt met 304 zolang er niets veranderd is)
en bouwt de `<img>`-tags. Zo verschijnen nieuwe foto's zonder rebuild of redeploy.

Een **nieuwe meet-up** vraagt wel een release: die heeft een contentbestand met
`photos.album` nodig. Foto's toevoegen aan een bestaand album niet.

## Waarom er niets gekopieerd wordt

`modules/immich.nix` zet `image.preview` op WebP met `size = 800`. Dat is de **korte
zijde** (`fit: outside`): een liggende foto van 3:2 wordt ongeveer 1205×800 (~155 kB).
Precies wat een galerij met drie kolommen nodig heeft.

Omdat de preview daarmee even zwaar is als een lokale kopie, slaat de dienst niets op.
Nginx proxyt `/immich/<asset-id>.webp` naar Immich, met de API-sleutel in een header. Dat
scheelt een tweede exemplaar op schijf (37 MB bij acht albums van dertig foto's), een
resize-stap en het opruimen van albums die verdwijnen.

Het manifest is de enige state: het houdt de volgorde, de afmetingen (berekend uit de
verhouding van het origineel) en de wijzigingstijd per asset. Die tijd gaat als `?v=` mee
in de foto-URL, zodat een vervangen foto een nieuwe URL krijgt ondanks de lange
browsercache.

**De prijs:** Immich is nu een runtime-afhankelijkheid van de galerij. Valt Immich weg, dan
tonen de foto-URL's een fout en blijft de galerij leeg; de rest van de pagina werkt. De
gemiddelde belasting is klein — 8 meet-ups van 30 foto's is 240 previews van ~155 kB, en
door `loading="lazy"` vraagt een bezoeker eerst drie tot zes foto's. De burst bij een verse
meet-up is het punt waarop de J3455 het kan merken; `proxy_cache` is dan de terugvaloptie.

Let op: een instellingswijziging geldt alleen voor **nieuwe** uploads. Bestaande assets
houden hun oude preview tot je in Immich de thumbnail-job opnieuw draait (Administratie →
Taken); dat is niet omkeerbaar.

## Wat de dienst niet doet

- Geen album aanmaken of wijzigen; het album moet bestaan.
- Geen share-link aanmaken. De albums blijven privé.
- De website bouwen. `./release.sh` blijft de enige manier waarop de site verandert.

## Foutgedrag

- **Immich onbereikbaar**: de dienst exit 1, het vorige manifest blijft staan (getest). Bij
  een bezoek geeft de foto-URL een foutstatus: de galerij blijft leeg, de pagina werkt.
- **Album bestaat niet of is leeg**: die meet-up wordt overgeslagen; het vorige manifest
  blijft staan.
- **Geen JavaScript**: geen galerij. Bewust geaccepteerd.
- **Geen meet-up-lijst** (nog geen release gedaan): de dienst meldt het en exit 0, zodat de
  timer op een verse installatie niet blijft falen. Productie en test worden allebei
  gelezen; een test-release schrijft de lijst alleen in de test-webroot.
- **Onderbroken run**: het manifest gaat eerst naar een tijdelijke map en wordt daarna in
  één keer verplaatst, zodat er nooit een half manifest staat.

## Testen

```bash
nix build .#checks.x86_64-linux.cckafe-photos -L
```

De test draait `fetch.sh` tegen een nep-Immich (`stub_server.py`) en controleert het
manifest (asset-id's, berekende afmetingen voor liggend en staand), dat er geen
fotobestanden en geen preview-request bijkomen, dat een verdwenen album het vorige manifest
laat staan, dat een oud fotobestand bij de volgende run verdwijnt, een leeg album, een
onbereikbare Immich en dat er geen share-link wordt gebruikt.

## Testen

```bash
nix build .#checks.x86_64-linux.cckafe-photos -L
```

De test draait `fetch.sh` tegen een nep-Immich (`stub_server.py`) en controleert het
manifest, het overnemen van een WebP-preview (identieke bytes), het verkleinen van een te
breed panorama, het omzetten van een JPEG-preview, een ontbrekend album, een leeg album, een
onbereikbare Immich en dat er geen share-link wordt gebruikt.
