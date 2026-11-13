# contact-mailer Specification

## Purpose
Een herbruikbare mailer voor contactformulieren van statische websites op malandro: verstuurt het formulier per mail, met een origin-whitelist, Cap-validatie en rate limiting.

## Requirements

### Requirement: NixOS module biedt configureerbare contactformulier mailer

De `services.contactMailer` module SHALL een PHP-FPM pool en nginx vhost aanmaken wanneer `enable = true` is ingesteld. De module MUST volledig declaratief zijn: het PHP script wordt gegenereerd via `pkgs.writeTextFile` en niet handmatig op het systeem geplaatst.

#### Scenario: Module ingeschakeld met recipient

- **WHEN** `services.contactMailer.enable = true` en `recipients` bevat minimaal één domein-emailadres paar
- **THEN** start een PHP-FPM pool als systemd service op malandro
- **THEN** is een nginx vhost `mailer.toorren.net` bereikbaar met een POST endpoint op `/send`

#### Scenario: Module uitgeschakeld

- **WHEN** `services.contactMailer.enable = false` of de module niet geïmporteerd is
- **THEN** worden geen PHP-FPM pool en geen nginx vhost aangemaakt

### Requirement: Contactformulier POST verwerkt en verstuurt email

Het `/send` endpoint SHALL een traditionele HTML form POST (`application/x-www-form-urlencoded`) verwerken met de velden `naam`, `email`, `bericht`, en `website` (honeypot). Bij succes MUST de gebruiker teruggestuurd worden naar de pagina van herkomst met een bevestigingsboodschap.

#### Scenario: Geldig formulier ingediend

- **WHEN** een POST request binnenkomt van een toegestaan domein met geldige Cap token, leeg honeypot veld, en gevulde velden naam/email/bericht
- **THEN** verstuurt het script een email via `mail()` naar het geconfigureerde ontvangst-adres voor dat domein
- **THEN** geeft het script een HTTP 200 terug met bevestigingstekst of redirect

#### Scenario: Honeypot veld ingevuld

- **WHEN** het `website` veld in de POST niet leeg is
- **THEN** geeft het script een HTTP 200 terug zonder email te versturen (stil negeren)

### Requirement: Origin whitelist beperkt toegang tot geconfigureerde domeinen

Het PHP script MUST de `HTTP_ORIGIN` of `HTTP_REFERER` header valideren tegen de domeinen geconfigureerd in `recipients`. Requests van niet-geconfigureerde domeinen MUST geweigerd worden.

#### Scenario: Request van toegestaan domein

- **WHEN** de Origin header overeenkomt met een domein in `recipients`
- **THEN** verwerkt het script de request

#### Scenario: Request van onbekend domein

- **WHEN** de Origin header niet overeenkomt met een geconfigureerd domein
- **THEN** geeft het script HTTP 403 terug en verstuurt geen email

#### Scenario: Site leest de status van het antwoord

- **WHEN** een request van een toegestaan domein een foutstatus krijgt (bijvoorbeeld
  429 als de limiet bereikt is)
- **THEN** bevat de response `Access-Control-Allow-Origin` met de origin van dat
  domein, zodat de site de status kan lezen en zelf de melding kan tonen
- **AND** geldt dat ook voor de redirect na een geslaagde POST, zodat de site die
  met `fetch` kan afhandelen

### Requirement: Cap (self-hosted) token wordt server-side gevalideerd

Het PHP script MUST het `cap-token` (geleverd door de Cap-widget) server-side valideren via de self-hosted Cap siteverify-API (`${capBaseUrl}/${capSiteKey}/siteverify`) met de key-secret uit `capSecretFile`. De request MUST een JSON-body `{"secret": ..., "response": ...}` (het widget-token gaat mee als `response`) met `Content-Type: application/json` gebruiken. Requests zonder geldig token MUST geweigerd worden.

#### Scenario: Geldig Cap token

- **WHEN** het `cap-token` veld aanwezig is en de Cap siteverify-API `success: true` teruggeeft
- **THEN** gaat het script door met verwerking van het formulier

#### Scenario: Ontbrekend of ongeldig token

- **WHEN** het token ontbreekt of de Cap siteverify-API geeft `success: false` terug
- **THEN** geeft het script HTTP 403 terug en verstuurt geen email

### Requirement: Nginx rate limiting beperkt POST requests per IP

De nginx configuratie MUST een `limit_req_zone` instellen van maximaal 5 requests per minuut per IP-adres voor het `/send` endpoint. Een burst van maximaal 3 requests MUST toegestaan zijn zonder vertraging.

#### Scenario: IP overschrijdt rate limit

- **WHEN** een IP-adres meer dan 5 POST requests per minuut verstuurt naar `/send`
- **THEN** geeft nginx HTTP 429 terug voor de overtollige requests

#### Scenario: Normaal gebruik binnen rate limit

- **WHEN** een IP-adres 1 POST request per formulierbezoek verstuurt
- **THEN** wordt de request doorgestuurd naar PHP-FPM zonder vertraging

### Requirement: Ontvangst-emailadres is configureerbaar per domein

De module MUST een `recipients` optie bieden van type `attrsOf str` waarbij de sleutel het brondomein is en de waarde het ontvangst-emailadres. Meerdere domeinen MUST tegelijk geconfigureerd kunnen worden.

#### Scenario: Één domein geconfigureerd

- **WHEN** `recipients = { "wereldvanbegrip.nl" = "wereldvanbegrip@toorren.net"; }`
- **THEN** worden formulieren van `wereldvanbegrip.nl` verstuurd naar `wereldvanbegrip@toorren.net`

#### Scenario: Meerdere domeinen geconfigureerd

- **WHEN** `recipients` bevat meerdere domein-emailadres paren
- **THEN** routeert het PHP script elke formuliersubmissie naar het bijbehorende ontvangst-emailadres op basis van de Origin header

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
