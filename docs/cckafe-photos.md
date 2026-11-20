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
                          |  preview overnemen (WebP) + manifest.json
                          v
              /var/lib/cckafe-photos/<slug>/   (niet in de webroot!)
                          |
                          |  nginx alias  /photos/  ->  die map
                          v
              cckafe.com/photos/<slug>/{manifest.json,001.webp}
                          ^
                          |  app.js haalt manifest.json op en bouwt de <img>-tags
              /meetups/<slug>/  (detailpagina, container in de HTML)
```

| Onderdeel | Waarde |
|---|---|
| Code | `modules/cckafe-photos/` (`default.nix`, `fetch.sh`, `package.nix`) |
| Host | malandro (`cckafe-photos.service` + `.timer`) |
| Sleutel | `secrets/immich-cckafe-photos-key.age` (account `webmaster@wereldvanbegrip.nl`) |
| Foto's op schijf | `/var/lib/cckafe-photos/<slug>/` (`nginx:nginx 0775`) |
| Publieke URL | `https://cckafe.com/photos/<slug>/` (nginx alias) |
| Lijst met albums | `/var/www/{,test.}cckafe.com/meetups/index.txt` (TSV, via HTTP geblokkeerd) |

## Waarom de foto's buiten de webroot staan

`release.sh` doet `rsync -a --delete` over `/var/www/cckafe.com`. Alles wat de fotodienst
daar neerzet zou bij elke release verdwijnen. De foto's staan daarom in `/var/lib` en nginx
serveert ze met een `alias` op `/photos/`.

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

## Waarom de preview wordt overgenomen

`modules/immich.nix` zet `image.preview` op WebP met `size = 800`. Dat is de **korte
zijde**: een liggende foto van 3:2 wordt ongeveer 1205×800 (~150 kB). Precies wat een
galerij met drie kolommen nodig heeft.

De dienst hercodeert die preview daarom niet meer; hij neemt het bestand ongewijzigd over.
`magick` blijft als vangnet staan voor twee gevallen:

- de preview is geen WebP (een asset van vóór de instellingswijziging, of Immich viel terug
  op het origineel) → omzetten naar WebP op kwaliteit 82;
- de foto is breder dan 1200px (een panorama) → terugbrengen naar 1200 breed.

Het formaat wordt uit de bestands-signatuur bepaald, niet uit de extensie van het origineel.
Een bron die `foto.jpg` heet levert immers WebP-bytes op, en zo krijgt het bestand op schijf
altijd de extensie die bij de inhoud past.

Let op: een instellingswijziging geldt alleen voor **nieuwe** uploads. Bestaande assets
houden hun oude preview tot je in Immich de thumbnail-job opnieuw draait (Administratie →
Taken); dat is niet omkeerbaar.

## Wat de dienst niet doet

- Geen album aanmaken of wijzigen; het album moet bestaan.
- Geen share-link aanmaken. De albums blijven privé.
- De website bouwen. `./release.sh` blijft de enige manier waarop de site verandert.

## Foutgedrag

- **Immich onbereikbaar**: de dienst exit 1, de vorige foto's blijven staan (getest).
- **Album bestaat niet of is leeg**: die meet-up blijft zonder galerij; de vorige foto's
  blijven staan.
- **Geen JavaScript**: geen galerij. Bewust geaccepteerd.
- **Geen meet-up-lijst** (nog geen release gedaan): de dienst meldt het en exit 0, zodat de
  timer op een verse installatie niet blijft falen. Productie en test worden allebei
  gelezen; een test-release schrijft de lijst alleen in de test-webroot.
- **Onderbroken run**: foto's en manifest gaan eerst naar een tijdelijke map en worden
  daarna in één keer verplaatst, zodat er nooit een half manifest staat.

## Testen

```bash
nix build .#checks.x86_64-linux.cckafe-photos -L
```

De test draait `fetch.sh` tegen een nep-Immich (`stub_server.py`) en controleert het
manifest, het overnemen van een WebP-preview (identieke bytes), het verkleinen van een te
breed panorama, het omzetten van een JPEG-preview, een ontbrekend album, een leeg album, een
onbereikbare Immich en dat er geen share-link wordt gebruikt.
