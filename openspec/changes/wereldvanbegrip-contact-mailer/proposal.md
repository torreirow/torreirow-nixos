## Why

wereldvanbegrip.nl is een statische Hugo site zonder server-side logica — bezoekers kunnen momenteel niet rechtstreeks contact opnemen via de website. Er is een veilig, server-side contactformulier nodig dat gebruikmaakt van de bestaande Postfix/AWS SES infrastructuur op malandro.

## What Changes

- Nieuwe NixOS module `modules/mailer.nix` met PHP-FPM pool en nginx vhost `mailer.toorren.net`
- PHP contactformulier script volledig declaratief gegenereerd via `pkgs.writeTextFile`
- Configureerbare ontvangst-emailadressen per domein via NixOS module opties (`attrsOf str`)
- Vijf beveiligingslagen: nginx rate limiting, Origin whitelist, honeypot veld, Cloudflare Turnstile server-side validatie, fail2ban filter op 403-responses
- Nieuw agenix secret `secrets/turnstile-secret.age` voor Cloudflare Turnstile
- `modules/nginx-wereldvanbegrip.nix` uitgebreid met contactformulier HTML
- `hosts/malandro/configuration.nix` importeert de nieuwe module
- `secrets/secrets.nix` krijgt het nieuwe Turnstile secret

## Capabilities

### New Capabilities

- `contact-mailer`: NixOS module die een herbruikbare PHP-FPM contactformulier mailer biedt met configureerbare ontvangers per domein en gelaagde beveiliging

### Modified Capabilities

*(geen bestaande specs wijzigen)*

## Impact

- **Nieuw**: PHP-FPM draait voor het eerst als host-service op malandro (los van Docker containers)
- **Postfix**: geen wijzigingen; PHP `mail()` gebruikt de bestaande AWS SES relay transparant
- **Nginx**: nieuwe vhost `mailer.toorren.net`, rate limiting zone toegevoegd
- **Cloudflare**: Turnstile widget vereist op het formulier; secret key nodig uit Cloudflare dashboard
- **Agenix**: nieuw secret `secrets/turnstile-secret.age` aan te maken en te versleutelen
