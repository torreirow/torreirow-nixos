## ADDED Requirements

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

- **WHEN** een POST request binnenkomt van een toegestaan domein met geldige Turnstile token, leeg honeypot veld, en gevulde velden naam/email/bericht
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

### Requirement: Cloudflare Turnstile token wordt server-side gevalideerd

Het PHP script MUST het `cf-turnstile-response` token server-side valideren via de Cloudflare Turnstile API (`https://challenges.cloudflare.com/turnstile/v0/siteverify`) met de secret key uit `turnstileSecretFile`. Requests zonder geldig token MUST geweigerd worden.

#### Scenario: Geldig Turnstile token

- **WHEN** het `cf-turnstile-response` veld aanwezig is en de Cloudflare API bevestigt het token als geldig
- **THEN** gaat het script door met verwerking van het formulier

#### Scenario: Ontbrekend of ongeldig token

- **WHEN** het token ontbreekt of de Cloudflare API geeft `success: false` terug
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
