# Proposal

## Why

De contactmailer remt op 3 berichten per uur en 10 per dag per ontvanger. Dat is
passend voor contactformulieren, maar blokkeert een meet-up waar zich tien mensen in
een uur aanmelden: de vierde krijgt een 429. De rem moet per formuliersoort kunnen
verschillen, zodat één gedeelde teller legitieme drukte niet als spam behandelt.

## What Changes

- Het `/send`-endpoint accepteert een optioneel veld `soort` (`contact` of `signup`,
  standaard `contact`); onbekende waarden vallen terug op `contact`.
- Limieten worden per soort geconfigureerd: `limits.kinds.<soort>` met `perHour` en
  `perDay`. Het bestaande `totalPerDay` blijft als harde plafondrem over alle soorten.
- Nieuwe limiet per IP per dag (`limits.perIpPerDay`, standaard 8), geteld met een
  gehasht IP (SHA-256 met salt), niet met het ruwe adres.
- Dedupe: dezelfde `email` + `soort` + `meetup` binnen 24 uur levert geen tweede mail
  op (stil HTTP 200).
- Kill switch: bestaat `${stateDir}/disabled`, dan antwoordt `/send` met 503 en een
  nette melding; geen rebuild nodig.
- Standaardwaarden: contact 3/uur en 10/dag, signup 30/uur en 80/dag, totaal 150/dag,
  8 per IP per dag.

## Capabilities

### New Capabilities

Geen.

### Modified Capabilities

- `contact-mailer`: limieten per formuliersoort, per-IP-limiet, dedupe en een kill
  switch naast de bestaande origin-whitelist, Cap-validatie en nginx-rate-limit.

## Impact

- `modules/mailer.nix` (PHP-script, opties, `ratelimit.json`-formaat).
- `hosts/malandro/configuration.nix` (limieten en eventueel `recipients`).
- Geen wijziging aan de sites: die sturen `soort` mee, en zonder dat veld geldt het
  oude gedrag.
- Rollback: limieten zijn additief; de module terugzetten op de vorige commit herstelt
  het oude gedrag, het `ratelimit.json` blijft compatibel (extra velden worden
  genegeerd).
