## ADDED Requirements

### Requirement: hCaptcha server-side verificatie
De service SHALL het `h-captcha-response` veld uit de POST body verifiëren via een HTTPS POST naar `https://api.hcaptcha.com/siteverify` met de geconfigureerde secret key. Verzoeken zonder geldige hCaptcha response MOETEN worden geweigerd.

#### Scenario: Geldige hCaptcha response
- **WHEN** een POST wordt gedaan met een geldig `h-captcha-response` token dat door hCaptcha API als `"success": true` wordt bevestigd
- **THEN** gaat de verwerking verder naar de volgende validatiestap

#### Scenario: Ongeldige hCaptcha response
- **WHEN** een POST wordt gedaan met een ongeldig of verlopen `h-captcha-response` token
- **THEN** retourneert de service HTTP 403 met body `{"ok": false, "error": "captcha verification failed"}`

#### Scenario: Ontbrekende hCaptcha response
- **WHEN** een POST wordt gedaan zonder `h-captcha-response` veld
- **THEN** retourneert de service HTTP 403 met body `{"ok": false, "error": "captcha verification failed"}`

#### Scenario: hCaptcha API timeout
- **WHEN** de hCaptcha API niet reageert binnen 5 seconden
- **THEN** retourneert de service HTTP 500 met body `{"ok": false, "error": "internal error"}` zodat de gebruiker het opnieuw kan proberen

### Requirement: Origin header validatie
De service SHALL de `Origin` HTTP header controleren tegen de `allowedOrigins` lijst van het token. Verzoeken van niet-toegestane origins MOETEN worden geweigerd.

#### Scenario: Toegestane origin
- **WHEN** een POST wordt gedaan met `Origin: https://wereldvanbegrip.nl` en die origin staat in `allowedOrigins` van het token
- **THEN** gaat de verwerking verder

#### Scenario: Niet-toegestane origin
- **WHEN** een POST wordt gedaan met `Origin: https://spam.example.com` die niet in `allowedOrigins` staat
- **THEN** retourneert de service HTTP 403 met body `{"ok": false, "error": "origin not allowed"}`

#### Scenario: Ontbrekende Origin header
- **WHEN** een POST wordt gedaan zonder `Origin` header (bijv. direct curl verzoek)
- **THEN** retourneert de service HTTP 403 met body `{"ok": false, "error": "origin not allowed"}`

### Requirement: Honeypot veld check
De service SHALL het veld `_gotcha` controleren. Als dit veld aanwezig is én een niet-lege waarde heeft, MOET het verzoek stilzwijgend worden geaccepteerd (HTTP 200 `{"ok": true}`) maar NIET worden verwerkt, zodat bots geen foutmelding zien die hen zou kunnen sturen om het veld te vermijden.

#### Scenario: Honeypot veld gevuld door bot
- **WHEN** een POST wordt gedaan met `_gotcha=bot@spam.com`
- **THEN** retourneert de service HTTP 200 met `{"ok": true}` maar wordt er geen email verstuurd

#### Scenario: Honeypot veld leeg (normale gebruiker)
- **WHEN** een POST wordt gedaan met `_gotcha=` (leeg)
- **THEN** gaat de verwerking normaal verder
