# Tasks

## 1. Contactadres

- [x] 1.1 Zet `LARGE_FILE_CONTACT` op `eghmedia@evangelischegemeente.org` in `modules/filedrop.nix` en `pkgs/filedrop/dev.sh`. Controle: `grep -rn taakgroepbeeldengeluid modules pkgs docs` geeft niets.
- [x] 1.2 Pas het contactadres aan in de tabel van `docs/filedrop.md`. Controle: dezelfde grep als bij 1.1.

## 2. Hero-achtergrond

- [x] 2.1 Zet `Dusk_To_Dawn_1b.jpg` om naar `pkgs/filedrop/hero.webp` (1600×900, `magick … -resize 1600x900 -quality 72`). Is de kopie in de scratchpad weg, download hem dan opnieuw uit de Dropbox-map. Controle: het bestand is ≤ 120 KB.
- [x] 2.2 Embed `hero.webp` in `main.go` en serveer het op `/hero.webp` als `image/webp`, met dezelfde `Cache-Control` als `/logo.png`. Controle: een nieuwe test in `main_test.go` (status 200, juiste Content-Type).
- [x] 2.3 Geef `.hero` in `index.html` de achtergrond `url(/hero.webp) center / cover, var(--sunset)`. Kies de positie zo dat logo en titel op het donkere deel staan. Haal de verwijzing naar `egh-stijl.md` uit het CSS-commentaar. Controle: in `dev.sh` zijn logo en titel leesbaar op telefoonbreedte (~375px) en op desktop, en het formulier is wit.

## 3. Blenda Script (in de repo)

- [x] 3.1 Download Blenda Script van dafont, zet de TTF met `woff2_compress` (`nix shell nixpkgs#woff2`) om naar `pkgs/filedrop/fonts/BlendaScript.woff2` en neem de licentietekst uit het zip-bestand mee als `fonts/BlendaScript-LICENSE.txt`. Controle: beide bestanden bestaan en de woff2 is kleiner dan 100 KB.
- [x] 3.2 Embed de woff2 en serveer hem op `/fonts/blenda-script.woff2` als `font/woff2`. Controle: een test in `main_test.go` (status 200, juiste Content-Type).
- [x] 3.3 Voeg in `index.html` een `@font-face` voor Blenda Script toe met `font-display: swap`. Pas het toe op `.subtitle .big` en haal daar `font-weight: 700` en `font-style: italic` weg. Controle: in `dev.sh` staat "upload" in het script-lettertype.

## 4. Letter Gothic Std (buiten de repo)

- [x] 4.1 Maak in `main.go` de route `/fonts/letter-gothic.woff2`. Die leest bij elk verzoek `$FONT_DIR/LetterGothicStd.woff2` (standaard is `FONT_DIR` gelijk aan `$STATE_DIRECTORY/fonts`) en geeft 404 als het bestand ontbreekt. Controle: tests met een lege tijdelijke map (404) en met een bestand dat er daarna in gezet is (200, `font/woff2`), zonder herstart.
- [x] 4.2 Laat `dev.sh` `FONT_DIR="$PWD/dev-fonts"` zetten en voeg `dev-fonts/` toe aan `pkgs/filedrop/.gitignore`. Controle: `git check-ignore pkgs/filedrop/dev-fonts/x.woff2` vindt een match.
- [x] 4.3 Voeg een test toe die faalt als er onder `pkgs/filedrop/`, buiten `dev-fonts/`, een bestand staat met `LetterGothic` in de naam (hoofdletterongevoelig). Controle: `go test ./...` slaagt, en faalt met een tijdelijk dummybestand.
- [x] 4.4 Voeg in `index.html` een `@font-face` met `font-display: swap` toe en de font-stack `"Letter Gothic Std", Roboto, Inter, "Helvetica Neue", Helvetica, Arial, sans-serif` voor `h1`, `.subtitle .small` en `h2`. Body, labels, velden en meldingen houden de Roboto-stack. Controle: in `dev.sh` zonder `dev-fonts` ziet de pagina eruit zoals nu en werkt insturen; met een eigen kopie in `dev-fonts` staan de koppen in Letter Gothic.

## 5. Pagina-eisen en documentatie

- [x] 5.1 Voeg in `main_test.go` een test toe die alle `url(...)`-, `src=`- en `href=`-waarden in `index.html` verzamelt en alleen relatieve paden toestaat, plus de `{{CAP_ENDPOINT}}`-placeholder en de jsdelivr Cap-widget. Controle: `cd pkgs/filedrop && go test ./...` slaagt, ook de bestaande `TestPageLayout`.
- [x] 5.2 Vul `docs/filedrop.md` aan met:
  - fonts en achtergrond: welk lettertype waar, en waarom Letter Gothic niet in de repo staat;
  - de handmatige stap `sudo install -Dm644 LetterGothicStd.woff2 /var/lib/private/filedrop/fonts/LetterGothicStd.woff2`;
  - de map `dev-fonts` in "Lokaal testen".

  Controle: het commando in de doc klopt met de standaardwaarde van `FONT_DIR` en de bestandsnaam in `main.go`.

## 6. Integratie op malandro

- [x] 6.1 Rebuild malandro (dat doet de gebruiker zelf). Controle: `curl -sI https://eghupload.toorren.net/hero.webp` en `/fonts/blenda-script.woff2` geven 200, en `/fonts/letter-gothic.woff2` geeft 404 zolang het font er nog niet staat.
- [x] 6.2 Zet de gelicentieerde Letter Gothic-woff2 op malandro zoals de doc beschrijft. Controle: zonder herstart geeft `/fonts/letter-gothic.woff2` 200. In de browser staan de koppen in Letter Gothic en toont het netwerktabblad geen nieuwe externe verzoeken.

## Workflow follow-up

- Voeg bij het archiveren de delta samen met `openspec/specs/filedrop/spec.md` (nieuw contactadres en vijf nieuwe requirements) en werk de CHANGELOG bij.
