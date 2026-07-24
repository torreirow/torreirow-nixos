## ADDED Requirements

### Requirement: POST endpoint verwerkt formulierdata
De service SHALL een HTTP POST endpoint aanbieden op `/submit` dat `application/x-www-form-urlencoded` of `multipart/form-data` accepteert en alle veldwaarden (behalve interne velden) als plain text email verstuurt via localhost SMTP (poort 25).

#### Scenario: Succesvolle formulierinzending
- **WHEN** een POST naar `/submit` wordt gedaan met een geldig token, geldige hCaptcha response, correcte Origin header en leeg honeypot veld
- **THEN** retourneert de service HTTP 200 met JSON body `{"ok": true}` en is een email verstuurd naar het geconfigureerde ontvanger adres

#### Scenario: Email onderwerp en body opmaak
- **WHEN** een formulier wordt verwerkt met velden `name=Jan`, `email=jan@example.com`, `message=Hallo`
- **THEN** heeft de email onderwerp `[Formulier: <token naam>] Nieuw bericht van Jan` en bevat de body alle veldwaarden behalve `_token`, `_honeypot` en `h-captcha-response`

### Requirement: JSON response voor AJAX gebruik
De service SHALL altijd JSON retourneren: `{"ok": true}` bij succes of `{"ok": false, "error": "<reden>"}` bij een fout. HTTP statuscodes: 200 bij succes, 400 bij validatiefouten, 403 bij geblokkeerde verzoeken, 500 bij interne fouten.

#### Scenario: Foutieve aanvraag geeft JSON terug
- **WHEN** een POST wordt gedaan zonder `_token` veld
- **THEN** retourneert de service HTTP 400 met body `{"ok": false, "error": "missing token"}`

#### Scenario: Server fout geeft JSON terug
- **WHEN** de SMTP verbinding naar postfix mislukt
- **THEN** retourneert de service HTTP 500 met body `{"ok": false, "error": "internal error"}`

### Requirement: CORS headers per token
De service SHALL een `Access-Control-Allow-Origin` header meesturen in de response, ingesteld op de Origin van het verzoek — maar alleen als die Origin voorkomt in de `allowedOrigins` lijst van het bijbehorende token.

#### Scenario: Toegestane origin krijgt CORS header
- **WHEN** een POST komt van `https://wereldvanbegrip.nl` en die origin staat in `allowedOrigins` van het token
- **THEN** bevat de response `Access-Control-Allow-Origin: https://wereldvanbegrip.nl`

#### Scenario: OPTIONS preflight request
- **WHEN** een OPTIONS request wordt ontvangen op `/submit`
- **THEN** retourneert de service HTTP 204 met correcte CORS headers zodat browser preflight succesvol is

### Requirement: Interne velden worden niet in email opgenomen
De service SHALL de velden `_token`, `_honeypot` en `h-captcha-response` niet opnemen in de email body.

#### Scenario: Interne velden gefilterd
- **WHEN** de POST body `_token=abc&name=Jan&_honeypot=&h-captcha-response=xxx&message=Hoi` bevat
- **THEN** bevat de email body alleen `name: Jan` en `message: Hoi`
