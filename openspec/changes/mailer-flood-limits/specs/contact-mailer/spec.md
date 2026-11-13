# Spec Delta

## ADDED Requirements

### Requirement: Formuliersoort bepaalt de limietbucket

Het `/send`-endpoint SHALL een optioneel veld `soort` accepteren (`contact` of
`signup`, standaard `contact`) en de limieten per soort toepassen via
`limits.kinds.<soort>` (`perHour`, `perDay`). Onbekende waarden SHALL als `contact`
gelden. Het bestaande `totalPerDay` SHALL over alle soorten samen blijven gelden.

#### Scenario: Aanmelding binnen het ruimere budget

- **WHEN** een POST met `soort=signup` binnenkomt en de signupbucket heeft nog ruimte
- **THEN** wordt de mail verstuurd, ook als de contactbucket in hetzelfde uur al vol is

#### Scenario: Aanmeldbucket vol

- **WHEN** het aantal `signup`-berichten in het laatste uur gelijk is aan
  `limits.kinds.signup.perHour`
- **THEN** antwoordt het endpoint met HTTP 429 en wordt er geen mail verstuurd

#### Scenario: Onbekende soort

- **WHEN** een POST `soort=nieuwsbrief` meestuurt
- **THEN** gelden de limieten van `contact`

### Requirement: Per-IP-limiet per dag met gehasht adres

Het PHP script SHALL per IP-adres per 24 uur maximaal `limits.perIpPerDay` berichten
toestaan (standaard 8). Het IP SHALL alleen gehasht (SHA-256 met salt) in
`ratelimit.json` worden opgeslagen, niet als ruw adres.

#### Scenario: IP overschrijdt daglimiet

- **WHEN** één IP-adres meer berichten verstuurt dan `limits.perIpPerDay` binnen 24 uur
- **THEN** antwoordt het endpoint met HTTP 429 en wordt er geen mail verstuurd

#### Scenario: Geen ruwe IP-adressen op schijf

- **WHEN** `ratelimit.json` wordt bekeken
- **THEN** bevatten de regels een hash en geen leesbaar IP-adres

### Requirement: Dubbele aanmelding levert één mail

Het PHP script SHALL een bericht met dezelfde `email`, `soort` en `meetup` binnen 24
uur niet nog eens versturen, en SHALL in dat geval HTTP 200 teruggeven zonder
verdere uitleg.

#### Scenario: Tweede keer verzenden

- **WHEN** dezelfde bezoeker dezelfde meet-up binnen 24 uur opnieuw aanmeldt
- **THEN** antwoordt het endpoint met HTTP 200 en wordt er geen tweede mail verstuurd

### Requirement: Noodstop zonder rebuild

Bestaat `${cfg.stateDir}/disabled`, dan SHALL het `/send`-endpoint met HTTP 503 en een
nette melding antwoorden en geen mail versturen. Het verwijderen van het bestand SHALL
het endpoint direct weer laten werken.

#### Scenario: Mailer gepauzeerd

- **WHEN** `disabled` in de state-map bestaat en een formulier wordt verzonden
- **THEN** antwoordt het endpoint met HTTP 503 en blijft de mail uit
