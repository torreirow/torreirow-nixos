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
| Max          | 25 MB per inzending; groter → contact taakgroepbeeldengeluid@… |
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

## Lokaal testen

```bash
pkgs/filedrop/dev.sh        # http://127.0.0.1:18111, stoppen met Ctrl-C
```

Inzendingen komen in `pkgs/filedrop/dev-share/` (genegeerd door git), Signal-meldingen verschijnen
in de terminal en de robotcontrole slaagt altijd (de widget zelf praat wel met cap.toorren.net).
`index.html` wordt bij elke paginaweergave opnieuw gelezen: aanpassen en F5. Na een Go-wijziging
het script herstarten. Pas als het lokaal goed is: rebuild van malandro.

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
