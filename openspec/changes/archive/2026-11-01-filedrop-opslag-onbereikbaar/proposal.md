# Proposal

## Why

Nextcloud staat elke nacht van 23:00 tot 09:00 uit, omdat bobadela1 dan uitgaat. Wie in die tijd
iets instuurt, krijgt nu "Er ging iets mis bij het opslaan. Probeer het later opnieuw." Daaruit
blijkt niet dat het om een vaste nachtpauze gaat, en ook niet wanneer het wel weer lukt. Bij een
echte storing weet de inzender bovendien niet bij wie hij terechtkan.

## What Changes

- Is de opslag onbereikbaar, dan krijgt de inzender een eigen melding. Daaronder vallen een
  verbindingsfout en een 502/503/504 van de Nextcloud-proxy. De melding zegt dat de opslag
  's nachts van 23:00 tot 09:00 uit staat en dat het daarna weer kan. Of de opslag bereikbaar is,
  volgt uit het antwoord van de opslag, niet uit de klok.
- Beide opslagfouten (onbereikbaar en overig) eindigen met het contactadres: "Gebeurt dit opnieuw?
  Neem dan contact op via eghmedia@…".
- De server antwoordt bij een onbereikbare opslag met HTTP 503 in plaats van 502.
- Niet in deze change: een waarschuwing vooraf op de pagina, en het teruggeven van het
  quotum-slot na een mislukte poging.

## Capabilities

### New Capabilities

_Geen._

### Modified Capabilities

- `filedrop`: er komen eisen bij voor de melding als de opslag onbereikbaar is, en voor het
  contactadres bij elke opslagfout.

## Impact

- `pkgs/filedrop/main.go`: herkent een onbereikbare opslag in MKCOL en PUT, en past de
  foutmeldingen aan.
- `pkgs/filedrop/main_test.go`: de fake backend kan "onbereikbaar" spelen.
- `docs/filedrop.md`: de meldingen bij een opslagfout.
