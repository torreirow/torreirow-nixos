# Design

## Context

`pkgs/filedrop` is een Go-binary die `index.html` en `logo.png` met `go:embed` meeneemt en zelf
serveert. De dienst draait met `DynamicUser` en `StateDirectory = "filedrop"`, dus op schijf
staat de state in `/var/lib/private/filedrop/` (via `$STATE_DIRECTORY` heet dat
`/var/lib/filedrop`). De enige externe bronnen van de pagina zijn het Cap-widget-script
(jsdelivr) en de Cap-API. De hero gebruikt nu alleen het CSS-verloop `--sunset`. `dev.sh` maakt
bij elke start een nieuwe `STATE_DIRECTORY` met `mktemp`.

Zie proposal.md voor het waarom en `specs/filedrop/spec.md` voor het gedrag.

## Goals / Non-Goals

**Goals:**
- Het Adobe-font staat nooit in git, ook niet als binair bestand of in de Nix store via de repo.
- Alles wat in de repo kan (Blenda Script, hero) zit in de binary. Er is dus geen extra stap bij
  het deployen.
- Een ontbrekend Letter Gothic-bestand is een cosmetisch verschil, geen storing.

**Non-Goals:**
- Het Cap-widget-script zelf hosten. Het blijft van jsdelivr komen; dat valt buiten deze change.
- Een licentie-administratie in de repo. Alleen de licentietekst van Blenda Script gaat mee,
  omdat het font in de repo staat.
- Andere Dusk To Dawn-varianten of een wisselende achtergrond.

## Decisions

### Letter Gothic uit een vaste map op de server, gelezen per verzoek
De route `/fonts/letter-gothic.woff2` leest bij elk verzoek
`$FONT_DIR/LetterGothicStd.woff2`. Bestaat het bestand niet, dan antwoordt de dienst met 404.
`FONT_DIR` is standaard `$STATE_DIRECTORY/fonts`. Op malandro is dat dus
`/var/lib/private/filedrop/fonts/`. Het bestand plaats je één keer als root, met mode 0644.

- Elke route serveert één vaste bestandsnaam, dus geen `http.FileServer` op een map. Zo is er
  geen maplijst en geen path traversal mogelijk.
- Er wordt per verzoek gelezen, niet bij de start. Een bestand dat later wordt neergezet, werkt
  dus zonder herstart. Het font is klein en de browser cachet het, dus de schijflees kost niets.
- **Alternatief: agenix.** Afgewezen. Het font is geen geheim, het bestand is binair en het zou
  ook in de versleutelde vorm in de publieke repo staan. Dat is juridisch twijfelachtig.
- **Alternatief: een niet-publieke flake-input of een `requireFile` in de Nix store.**
  Afgewezen. Dat maakt de build afhankelijk van een bestand buiten de repo en breekt
  `nixos-rebuild` op een verse machine.

### Fallback via de CSS-font-stack, geen JavaScript
`@font-face` voor Letter Gothic wijst naar `/fonts/letter-gothic.woff2`. De font-family is
`"Letter Gothic Std", Roboto, Inter, …, sans-serif`. Een 404 laat de browser stil terugvallen. Met
`font-display: swap` blijft de tekst altijd zichtbaar. De bestaande opmaak (hoofdletters,
spatiëring) blijft staan, zodat de fallback er net zo uitziet als nu.

### Blenda Script en de hero als embeds
- De TTF van dafont wordt één keer omgezet naar `fonts/BlendaScript.woff2` met `woff2_compress`
  (`nix shell nixpkgs#woff2`). Het gaat in de binary samen met `fonts/BlendaScript-LICENSE.txt`
  uit het zip-bestand.
- `Dusk_To_Dawn_1b.jpg` (3840×2160) wordt `hero.webp`: 1600×900, met `magick … -resize
  1600x900 -quality 72`. Het doel is minder dan 120 KB. Er is geen `<img>`: de afbeelding is een
  CSS-achtergrond, `background: url(/hero.webp) center / cover, var(--sunset)`. Laadt de
  afbeelding niet, dan blijft de gradient-laag over.
- Routes: `/hero.webp` (`image/webp`) en `/fonts/blenda-script.woff2` (`font/woff2`), met
  dezelfde `Cache-Control` als `/logo.png`.

### Waar welk lettertype
| Element                        | Lettertype                 |
|--------------------------------|----------------------------|
| `.subtitle .big` ("upload")    | Blenda Script → cursive    |
| cijfer in het sectierondje     | Roboto vet                 |
| alle andere tekst              | Letter Gothic Std → Roboto |

Bijgesteld na het bekijken van "EGH - Preek.pptx": de EGH-presentaties zetten ook lange
lopende tekst in Letter Gothic, en de gebruiker koos ervoor om dat ook voor labels en velden
te doen. Roboto wordt meegeleverd (OFL, Latijnse subset) als terugval.

Blenda Script heeft geen bold of italic. Daarom vervallen `font-weight: 700` en
`font-style: italic` op `.big`, zodat de browser geen nep-vet of nep-cursief maakt.

### dev.sh
`dev.sh` zet `FONT_DIR="$PWD/dev-fonts"`. Die map staat in `.gitignore`. Wie de echte look lokaal
wil zien, zet daar zijn eigen kopie neer. Zonder die kopie test je meteen de fallback.

## Risks / Trade-offs

- [Iemand commit per ongeluk het Adobe-font] → `.gitignore` sluit `dev-fonts/` uit, en een test
  faalt als er een bestand met `LetterGothic` in de naam onder `pkgs/filedrop/` staat.
- [De hero-afbeelding maakt de pagina zwaarder op mobiel] → WebP van maximaal ~120 KB, met
  `cover` en zonder `<img>`, dus het formulier rendert niet later.
- [Het witte logo en de tekst zijn slecht leesbaar op de lichte onderkant van 1b] → De hero
  heeft nu al onderin creme. Kies `background-position` zo dat het donkere deel achter logo en
  titel valt. Controleer dit in `dev.sh` op telefoonbreedte.
- [De woff2 van Letter Gothic heeft een andere interne familienaam] → `@font-face` geeft de naam
  zelf op, dus de interne naam doet niet ter zake.
- [Na een herinstallatie van malandro ontbreekt het font] → De pagina valt terug. De handmatige
  stap staat in `docs/filedrop.md`.

## Migration Plan

1. Bouw en test lokaal met `dev.sh`: eerst zonder `dev-fonts`, dan met.
2. Rebuild malandro.
3. Zet het font neer:
   `sudo install -Dm644 LetterGothicStd.woff2 /var/lib/private/filedrop/fonts/LetterGothicStd.woff2`
   Een herstart is niet nodig.
4. Rollback: een `git revert` en een rebuild. Het fontbestand mag blijven staan.
