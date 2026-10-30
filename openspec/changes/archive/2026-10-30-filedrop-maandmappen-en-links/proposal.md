# Proposal

## Why

De File Drop op `upload.toorren.net` zet inzendingen nu in een map met naam en e-mail in de
mapnaam. Dat zet persoonsgegevens in de mappenlijst en sorteert slecht. Daarnaast sturen mensen
het EGH Scherm Team vaak video's als link (YouTube, Facebook, Instagram, Vimeo). Die kunnen nu
niet via het formulier binnenkomen, alleen als bestand van maximaal 25 MB.

## What Changes

- **BREAKING (opslagindeling):** een inzending komt in `eghuploads/<JJJJ-MM>/<JJJJMMDD-UUMMSS>/`
  (tijdzone Europe/Amsterdam) in plaats van `JJJJ-MM-DD UU.MM - Naam (email)`. Valt dezelfde
  seconde twee keer, dan krijgt de tweede map het achtervoegsel `-2`. Bestaande mappen blijven
  staan.
- Naam, e-mail en tijdstip komen in `_afzender.txt` in de inzendmap.
- Zijn er in één inzending twee bestanden met dezelfde naam, dan krijgt de tweede een volgnummer
  (`foto (2).jpg`) in plaats van dat de upload faalt.
- Het formulier krijgt een optioneel blok met maximaal 5 videolinks, elk met een optioneel
  titelveld. Een inzending moet minstens één link of één bestand bevatten.
- Links worden alleen geaccepteerd als ze https zijn en hun host bij YouTube, Facebook,
  Instagram of Vimeo hoort.
- De links komen in `video-links.txt`: per item een nummer, een titel en de link, met een lege
  regel tussen de items. De titel is de ingevulde titel, anders de titel en auteur van de
  officiële oEmbed (YouTube, Vimeo), anders de platformnaam ("Facebook-video",
  "Instagram-reel").
- De Signal-melding noemt ook de links en de nieuwe mapnaam.
- Er komt geen bevestigingsmail aan de inzender (bewust buiten scope).

## Capabilities

### New Capabilities

- `filedrop`: het publieke uploadformulier op `upload.toorren.net`. Het beschrijft de
  toegangsdrempels (captcha, verplichte naam/e-mail, honeypot, quota, maximale grootte), de
  opslagindeling in de Nextcloud-share, het ontvangen van videolinks en de melding per
  inzending. Er is nog geen spec voor deze dienst. Deze change legt ook het gedrag vast dat al
  live staat.

### Modified Capabilities

(geen)

## Impact

- Code: `pkgs/filedrop/main.go`, `pkgs/filedrop/index.html`, eventueel een nieuw bestand voor
  link-validatie en oEmbed. `modules/filedrop.nix` alleen als er configuratie bijkomt.
- Externe afhankelijkheid: uitgaande HTTPS-aanroepen naar de oEmbed-endpoints van YouTube en
  Vimeo, met een korte time-out. Facebook en Instagram vragen een Meta-token en worden niet
  aangeroepen.
- Nextcloud-share `eghuploads` (account `nxceghmedia`): nieuwe mappenstructuur. Het opruimen van
  de oude test- en naammappen gebeurt met de hand.
- Docs: `docs/filedrop.md` (opslagindeling, links, voorbeeld van `video-links.txt`).
