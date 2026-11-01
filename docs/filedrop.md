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
| Kerknaam, "Media", sectiekoppen       | Letter Gothic Std, **alleen op malandro**         | `/fonts/letter-gothic.woff2` |
| Uitleg, labels, velden, meldingen     | Roboto-stack (systeemfont)                        | -                            |

- **Waarom Letter Gothic niet in de repo staat:** het is een Adobe-font. EGH heeft er een licentie
  voor, maar de repo is publiek en dan zou het bestand vrij te downloaden zijn. Ook niet via
  agenix: het is geen geheim en zou versleuteld alsnog in de publieke repo staan.
  `TestNoLicensedFontInRepo` faalt als er een `*LetterGothic*`-bestand in `pkgs/filedrop/` staat.
- **Ontbreekt het bestand**, dan geeft de route een 404 en toont de browser die teksten in de
  Roboto-stack; de pagina werkt verder gewoon. Een later neergezet bestand werkt zonder herstart
  (het wordt per verzoek gelezen).
- Blenda Script (Seniors Studio, dafont) is "Free for Personal and Commercial use", zie
  `fonts/BlendaScript-LICENSE.txt`. Het font is van zichzelf vet; daarom geen `font-weight: 700`.
- De bronbeelden van de hele "Dusk To Dawn"-reeks (12 stuks, 3840×2160) staan in de Dropbox-map
  van EGH; alleen 1b is in gebruik. Omzetten: `magick Dusk_To_Dawn_1b.jpg -resize 1600x900 -strip
  -quality 88 -define webp:method=6 hero.webp` (bij lagere kwaliteit zie je banding in het donker).

Letter Gothic op malandro neerzetten (eenmalig, en opnieuw na een herinstallatie). Heb je alleen een
`.otf`, zet die dan eerst om met `nix shell nixpkgs#woff2 -c woff2_compress LetterGothicStd.otf`:

```bash
sudo install -Dm644 LetterGothicStd.woff2 /var/lib/private/filedrop/fonts/LetterGothicStd.woff2
curl -sI https://eghupload.toorren.net/fonts/letter-gothic.woff2 | head -1   # 200
```

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

## Logs

```bash
journalctl -u filedrop -f    # "upload ok: N file(s) …" of de foutoorzaak
```
