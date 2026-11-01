# Proposal

## Why

De uploadpagina op `eghupload.toorren.net` heeft de EGH-kleuren al, maar nog niet de lettertypes
en de achtergrond uit de huisstijl. Daardoor lijkt de pagina minder op de rest van het
EGH-materiaal. Daarnaast is het contactadres voor grote bestanden
(`taakgroepbeeldengeluid@evangelischegemeente.org`) lang en lastig over te typen. Er bestaat nu
een korter adres: `eghmedia@evangelischegemeente.org`.

## What Changes

- Het contactadres voor inzendingen boven 25 MB wordt `eghmedia@evangelischegemeente.org`. Dat
  geldt voor de pagina, de foutmelding van de server en de documentatie.
- De grote titel "upload" in de hero krijgt het script-lettertype Blenda Script. Dat lettertype is
  vrij te gebruiken, ook commercieel, en zit in de binary.
- De kerknaam, het woord "Media" en de sectiekoppen krijgen Letter Gothic Std (Adobe). EGH heeft
  daar een licentie voor, maar de repo is publiek. Daarom staat het fontbestand niet in de repo
  maar alleen op malandro, in de state-map van de dienst. Ontbreekt het bestand, dan toont de
  pagina dezelfde tekst in het gewone sans-serif-lettertype, zonder fout.
- De hero krijgt de achtergrondfoto "Dusk To Dawn 1b" uit de EGH-huisstijl, verkleind tot een
  WebP-bestand in de binary. Het bestaande CSS-verloop blijft als terugval. Het formulier blijft
  wit.
- De lopende tekst en de invoervelden houden het huidige sans-serif-lettertype.
- De pagina doet ook na deze wijziging geen verzoeken naar andere servers dan de eigen dienst en
  de Cap-widget, net als nu bij het logo.
- Het CSS-commentaar verwijst niet meer naar het niet-bestaande `~/.claude/docs/egh-stijl.md`.

## Capabilities

### New Capabilities

_Geen._

### Modified Capabilities

- `filedrop`: het contactadres in "Maximale grootte per inzending" verandert. Er komt een nieuwe
  requirement voor de huisstijl-middelen: lettertypes en achtergrond worden door de eigen dienst
  geleverd, en de pagina blijft bruikbaar als het gelicentieerde lettertype ontbreekt.

## Impact

- `pkgs/filedrop/`: `index.html` (CSS en `@font-face`), `main.go` (nieuwe routes `/fonts/...` en
  `/hero.webp`, met de embeds), nieuwe bestanden `fonts/BlendaScript.woff2` en `hero.webp`, en de
  tests in `main_test.go`. Dit zijn extra binaire bestanden in de repo, ongeveer 100 KB.
- `pkgs/filedrop/dev.sh`: het nieuwe contactadres.
- `modules/filedrop.nix`: `LARGE_FILE_CONTACT`.
- Malandro: het Letter Gothic-bestand moet één keer handmatig in
  `/var/lib/private/filedrop/fonts/` worden gezet. Het hoort niet in de repo en ook niet in agenix,
  want het is geen geheim.
- `docs/filedrop.md`: contactadres, fonts, achtergrond en de handmatige stap.
- `openspec/specs/filedrop/spec.md`: bijgewerkt bij het archiveren.
