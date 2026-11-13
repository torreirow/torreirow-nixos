# File Drop (eghupload.toorren.net)

Uploadpagina waar anderen bestanden en/of videolinks bij ons neerzetten, met verplichte naam en
e-mail en een Cap-captcha. Ze zien geen inzendingen van anderen.

```
browser ── eghupload.toorren.net ── nginx ── filedrop (Go, :8102) ──┬─ cap.toorren.net/<key>/siteverify
                                                                ├─ nxc.toorren.net public WebDAV (share)
                                                                └─ signal-cli REST :8088 (melding)
```

| Onderdeel     | Waarde                                                   |
|---------------|----------------------------------------------------------|
| Pagina        | `https://eghupload.toorren.net` (oud `upload.` → 301-redirect) |
| Code          | `pkgs/filedrop/` (Go + `index.html`), `modules/filedrop.nix` |
| Nextcloud     | account `nxceghmedia`, map `eghuploads`, File Drop-share |
| Opslag        | `JJJJ-MM/JJJJMMDD-UUMMSS/` per inzending (zie hieronder) |
| Captcha       | Cap site-key "filedrop" (site-key in `modules/filedrop.nix`) |
| Geheimen      | `secrets/filedrop-env.age`: `CAP_SECRET`, `NEXTCLOUD_SHARE_TOKEN` |
| Melding       | Signal naar `SIGNAL_RECIPIENT` uit `signal-numbers.age`  |
| Mail          | zelfde tekst naar `eghupload@toorren.net` (Reply-To = inzender) |
| Max          | 25 MB per inzending; groter → contact `eghmedia@evangelischegemeente.org` |
| Quota         | zie hieronder; nginx daarnaast 6 req/min per IP (burst 3) |

## Pagina

Bedoeld voor mensen zonder technische kennis. Van boven naar beneden: logo (wit, op een donkere
balk), "Evangelische Gemeente Harderwijk" / "Media upload", een uitklapblok "Handleiding: hoe werkt
het insturen?" (standaard dicht), en dan de secties 1 Jouw gegevens, 2 Bestanden, "en/of",
3 Videolinks, 4 Bericht (optioneel, max 1000 tekens) en 5 Versturen ("Ik ben geen robot" net
boven de knop).

- Naam en e-mail onthoudt de browser na een geslaagde inzending (`localStorage`, sleutel
  `egh-gegevens`), zolang het vinkje "Onthoud mijn naam en e-mailadres op dit apparaat" aan staat
  (standaard aan). Uitvinken wist ze. Bewust geen cookie: de server hoeft ze niet terug te krijgen.
  Het vinkje heeft geen `name` en wordt dus niet meegestuurd.
- De handleiding zegt dat je na een fout opnieuw moet beginnen: een inzending is achteraf
  niet aan te passen (de share mag alleen aanmaken).
- Groter dan 25 MB: de inzender neemt contact op met het Scherm Team en krijgt dan een
  persoonlijk Erugo-instuurverzoek (`filesender.toorren.net`). Bewust geen grotere open upload:
  zo blijft de ruimte voor upload-spam klein.
- Alle teksten staan in `pkgs/filedrop/index.html`; meldingen van de server in `main.go`,
  `links.go` en `limits.go`. Geen woorden als upload/URL/captcha in zichtbare tekst (behalve de
  ondertitel): `TestPageLayout` bewaakt dat en de volgorde van de secties.
- De pagina toont de bestanden boven de links, maar verstuurt alle tekstvelden (ook links en
  `cap-token`) vóór de bestanden; de server weigert een link die na een bestand binnenkomt.
- Het logo zit in de binary (`logo.png`, van evangelischegemeente.org) en wordt op `/logo.png`
  geserveerd; er gaat geen verzoek naar de kerk-website.

## Huisstijl: lettertypes en achtergrond

Alles komt van de dienst zelf; de enige externe bron van de pagina is de robotcontrole (Cap).
`TestNoExternalAssets` bewaakt dat.

| Wat                                   | Bron                                              | Route                        |
|---------------------------------------|---------------------------------------------------|------------------------------|
| Achtergrond hero                      | `hero.webp` ("Dusk To Dawn 1b", 1600×900) in de binary | `/hero.webp`            |
| "upload" (titel)                      | Blenda Script, `fonts/BlendaScript.woff2` in de binary | `/fonts/blenda-script.woff2` |
| Alle andere tekst (zoals in de EGH-presentaties) | Letter Gothic Std, **alleen op malandro** | `/fonts/letter-gothic.woff2` |
| Terugval, en het cijfer in het sectierondje | Roboto (OFL, Latijnse subset, Regular/Bold/Italic) in de binary | `/fonts/roboto-*.woff2` |

- **Waarom Letter Gothic niet in de repo staat:** het is een Adobe-font. EGH heeft er een licentie
  voor, maar de repo is publiek en dan zou het bestand vrij te downloaden zijn. Ook niet via
  agenix: het is geen geheim en zou versleuteld alsnog in de publieke repo staan.
  `TestNoLicensedFontInRepo` faalt als er een `*LetterGothic*`-bestand in `pkgs/filedrop/` staat.
- **Ontbreekt het bestand**, dan geeft de route een 404 en toont de browser alle tekst in
  Roboto; de pagina werkt verder gewoon. Een later neergezet bestand werkt zonder herstart
  (het wordt per verzoek gelezen).
- Roboto komt uit `nixpkgs#roboto` (3.016), teruggebracht tot Latijn met `pyftsubset … --flavor=woff2`
  (samen ~64 KB); licentie in `fonts/Roboto-LICENSE.txt`. Gewicht 600 valt op Bold.
- Blenda Script (Seniors Studio, dafont) is "Free for Personal and Commercial use", zie
  `fonts/BlendaScript-LICENSE.txt`. Het font is van zichzelf vet; daarom geen `font-weight: 700`.
- De bronbeelden van de hele "Dusk To Dawn"-reeks (12 stuks, 3840×2160) staan in de Dropbox-map
  van EGH; alleen 1b is in gebruik. Omzetten: `magick Dusk_To_Dawn_1b.jpg -resize 1600x900 -strip
  -quality 88 -define webp:method=6 hero.webp` (bij lagere kwaliteit zie je banding in het donker).

Letter Gothic op malandro neerzetten (eenmalig, en opnieuw na een herinstallatie). Heb je alleen een
`.otf`, zet die dan eerst om met `nix shell nixpkgs#woff2 -c woff2_compress LetterGothicStd.otf`:

```bash
for f in LetterGothicStd LetterGothicStd-BoldSlanted; do
  sudo install -Dm644 $f.woff2 /var/lib/private/filedrop/fonts/$f.woff2
done
curl -sI https://eghupload.toorren.net/fonts/letter-gothic.woff2 | head -1               # 200
curl -sI https://eghupload.toorren.net/fonts/letter-gothic-bold-slanted.woff2 | head -1  # 200
```

`LetterGothicStd-BoldSlanted` is voor de vette, schuine sectiekoppen. Ontbreekt dat bestand, dan
maakt de browser het vet en schuin zelf na uit de gewone variant; dat is nauwelijks zichtbaar.

De map is de standaardwaarde van `FONT_DIR` (`$STATE_DIRECTORY/fonts`; door `DynamicUser` ligt
de state-map in `/var/lib/private/`).

## Lokaal testen

```bash
pkgs/filedrop/dev.sh        # http://127.0.0.1:18111, stoppen met Ctrl-C
```

Inzendingen komen in `pkgs/filedrop/dev-share/` (genegeerd door git), Signal-meldingen verschijnen
in de terminal en de robotcontrole slaagt altijd (de widget zelf praat wel met cap.toorren.net).
`index.html` wordt bij elke paginaweergave opnieuw gelezen: aanpassen en F5. Na een Go-wijziging
het script herstarten. Pas als het lokaal goed is: rebuild van malandro.

Letter Gothic lokaal zien: zet je eigen `LetterGothicStd.woff2` in `pkgs/filedrop/dev-fonts/`
(genegeerd door git; `dev.sh` zet `FONT_DIR` daarheen). Zonder dat bestand zie je de terugval.

## Opslagindeling

```
eghuploads/
+-- 2026-10/
    +-- 20261030-143210/
    |   +-- _afzender.txt      naam, e-mail, tijdstip, bestandenlijst, aantal links
    |   +-- video-links.txt    alleen als er links zijn ingestuurd
    |   +-- bericht.txt        alleen als er een bericht is ingevuld (staat niet in Signal)
    |   +-- foto.jpg
    |   +-- foto (2).jpg       tweede bestand met dezelfde naam
    +-- 20261030-143210-2/     tweede inzending in dezelfde seconde
```

- Tijd in Europe/Amsterdam. Naam en e-mail staan nooit in map- of bestandsnamen.
- De share mag alleen aanmaken (geen PROPFIND, niet overschrijven): "bestaat al" ziet de dienst
  alleen als 405 op MKCOL, en dubbele namen binnen een inzending krijgen een volgnummer.
- Géén `X-NC-Nickname`-header meesturen: op een File Drop zet Nextcloud uploads met een
  gastnaam in een eigen map met die naam (gezien op 30-10-2026), los van de indeling hierboven.
- Mappen van vóór 30-10-2026 (`JJJJ-MM-DD UU.MM - Naam (email)`) zijn niet omgezet.

## Videolinks

Maximaal 5 links per inzending, elk met een optionele titel. Toegestaan: alleen `https` met een
host (of subdomein) van `youtube.com`, `youtu.be`, `facebook.com`, `fb.watch`, `instagram.com` of
`vimeo.com`. Het pad wordt niet gecontroleerd (`/reel/`, `/reels/`, `/shorts/`, `/watch?v=`).

Titel per link: ingevuld door de inzender → anders oEmbed `Titel (Auteur)` voor YouTube en Vimeo
(time-out 5 s, pas na captcha en quota) → anders de platformnaam. Facebook en Instagram krijgen
geen oEmbed-aanroep: daarvoor is een Meta-app-token nodig, en de pagina schrapen als
Facebook-crawler doen we bewust niet. De link wordt exact zoals ingestuurd bewaard.

`video-links.txt` (UTF-8, CRLF):

```
1
Elephants Dream (Blender)
https://vimeo.com/1132937?fl=pl&fe=cm

2
Instagram-reel
https://www.instagram.com/reels/DfG9eQtuo5k
```

De lezer downloadt de video zelf; de dienst haalt geen video's op.

Tests: `cd pkgs/filedrop && go test ./...`; de echte oEmbed-endpoints met
`FILEDROP_LIVE=1 go test -run TestLiveOembed -v`.

## Waarom zo

- Nextcloud kent geen captcha en geen verplicht e-mailveld op een publieke share. Een
  captcha-pagina met daarna een redirect is omzeilbaar zodra de link bekend is. Daarom zet de
  dienst de bestanden zelf door, en blijft het share-token geheim (alleen in agenix; de repo is
  publiek).
- Naam, e-mail, `cap-token` en de links staan in het formulier vóór het bestandsveld. De dienst leest de
  multipart-stroom op volgorde en controleert alles voordat er één byte naar Nextcloud gaat.
- Bestanden worden gestreamd (chunked PUT), niet op malandro gebufferd.
- Honeypot-veld `website`: ingevuld → "Bedankt!" zonder opslag.

## Quota tegen misbruik

Sliding window van 24 uur in `/var/lib/filedrop/ratelimit.json` (blijft bij herstart staan).
Een slot telt pas na een geslaagde captcha, zodat bots zonder captcha het quotum niet opmaken.

| Limiet             | Waarde | Melding aan uploader                         |
|--------------------|--------|----------------------------------------------|
| Per IP per uur     | 3      | "maximum aantal uploads bereikt"             |
| Per IP per 24 uur  | 10     | idem                                         |
| Totaal per 24 uur  | 40     | "vandaag al veel geüpload" + 1× Signal-alert |
| Bytes per 24 uur   | 1 GB   | idem                                         |

Aanpassen: `LIMIT_*` in `modules/filedrop.nix`. Teller resetten: `sudo rm
/var/lib/private/filedrop/ratelimit.json && sudo systemctl restart filedrop`.

## Share-link of Cap-sleutel vervangen

```bash
cd secrets && ragenx -e filedrop-env.age   # CAP_SECRET=… / NEXTCLOUD_SHARE_TOKEN=…
sudo nixos-rebuild switch --flake .#malandro
```

Een nieuw share-token komt uit de link `https://nxc.toorren.net/s/<token>`. Controle dat het een
echte file drop is (geen leesrechten):

```bash
curl -s https://nxc.toorren.net/s/<token> | grep -o 'files_sharing-view" value="[^"]*' \
  | sed 's/.*value="//' | base64 -d   # moet "public-file-drop" geven
```

## Cap-server (capd)

De captcha draait lokaal op malandro (`modules/cap.nix`), niet bij een derde partij.

| Onderdeel | Waarde |
|-----------|--------|
| Image     | `tiago2/cap@sha256:e9cd4884…` (4.0.12); de server heet sinds v4 `capd` |
| Store     | `cap-valkey` (valkey 9) in `/data/external/cap/valkey` — site-keys, secrets, sessies |
| Events    | DuckDB in `/data/external/cap/events` (uid 1000), `DUCKDB_MEMORY_LIMIT=128MB` |
| Poort     | `127.0.0.1:3009`; nginx doet TLS op `cap.toorren.net` |
| Proxy     | nginx stuurt `X-Forwarded-For $remote_addr`; zet in het dashboard onder *Instance settings → Visitor location* de proxy op nginx, anders delen alle bezoekers één rate-limit-bucket |
| Health    | `GET /health` (200 = Valkey bereikbaar), `GET /health/live` |
| Admin     | dashboard op `https://cap.toorren.net` met `ADMIN_KEY` uit `cap-admin-key.age` (`/run/keys/wouter/cap-admin-key`) |

De container gebruikt `VALKEY_URL` (v4; v3 heette dat `REDIS_URL`) en mount het event-volume op
`/usr/src/app/data`. Zonder die mount is de analytics-historie weg bij elke container-herstart.

### Site-secret roteren

Het secret van een site-key staat alleen als hash in Valkey, dus een nieuwe waarde moet altijd in
twee stappen:

1. Dashboard → key openen → **Settings → Danger zone → Reset secret** (waarde wordt één keer getoond).
2. Agenix bijwerken: `cap-mailer-secret.age` (mailer) of `CAP_SECRET` in `filedrop-env.age`, dan
   `nixos-rebuild switch`. De mailer leest het bestand per request; **filedrop leest de env bij
   start**, dus `sudo systemctl restart filedrop` als de switch hem niet al herstartte.

Controleren zonder een captcha op te lossen: `POST /<key>/siteverify` met het secret en een
nep-token. `{"error":"Token not found"}` (404) betekent dat het secret klopt; `403 Invalid site key
or secret` betekent dat agenix nog de oude waarde heeft.

## Cap upgraden of terugrollen

Twee agenix-bestanden hangen aan Cap: `secrets/cap-mailer-secret.age` (contactmailer) en
`CAP_SECRET` in `secrets/filedrop-env.age` (deze dienst). Beide horen bij een eigen site-key op
`cap.toorren.net`.

Terugrolpad na een Cap-upgrade:

```bash
# op malandro, vóór de upgrade: snapshot van Valkey (keys, secrets, sessies)
sudo docker exec cap-valkey valkey-cli SAVE
sudo cp /data/external/cap/valkey/dump.rdb /data/external/cap/backup-$(date +%F).rdb

# terugrollen: digest in modules/cap.nix terugzetten, switch, en de snapshot terugplaatsen
sudo install -o 999 -g 999 -m 600 /data/external/cap/backup-<datum>.rdb \
  /data/external/cap/valkey/dump.rdb
sudo nixos-rebuild switch --flake .#malandro
```

Een op Cap 4 geroteerd secret kan Cap 3 niet lezen: na een terugrol moeten beide secrets opnieuw
gezet worden (in het dashboard van de draaiende versie) en daarna in `cap-mailer-secret.age` en
`filedrop-env.age`, gevolgd door een `switch`.

## Als opslaan mislukt

bobadela1, en daarmee Nextcloud, staat elke nacht van 23:00 tot 09:00 (zondag 08:00) uit. De proxy op
`nxc.toorren.net` antwoordt dan binnen ongeveer 3 s met 503 (zie `modules/nextcloud-proxy.nix`),
dus er treedt geen time-out op.

| Antwoord van de opslag                    | HTTP aan inzender | Melding                                                                 |
|-------------------------------------------|-------------------|-------------------------------------------------------------------------|
| verbindingsfout of 502/503/504 (MKCOL/PUT) | 503               | "De opslag is nu niet bereikbaar. Die staat elke nacht van 23:00 tot 09:00 uit (op zondag tot 08:00); probeer het daarna opnieuw." |
| een andere fout                           | 502               | "Er ging iets mis bij het opslaan. Probeer het later opnieuw."          |

Beide meldingen eindigen met "Gebeurt dit opnieuw? Neem dan contact op via
eghmedia@evangelischegemeente.org." In de dialoog staat daarachter een kleine "klik hier"-mailto-link
(onderwerp "Insturen lukt niet"). De dienst kijkt naar het antwoord van de opslag en niet naar
de klok. Een storing overdag krijgt daardoor dezelfde melding, en een verschoven nachtpauze vraagt
geen aanpassing. Een mislukte poging telt wel mee voor het quotum.

## Logs

```bash
journalctl -u filedrop -f    # "upload ok: N file(s) …" of de foutoorzaak
```
