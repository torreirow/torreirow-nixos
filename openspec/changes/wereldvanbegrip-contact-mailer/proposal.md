## Why

wereldvanbegrip.nl is een statische Hugo site zonder server-side logica — bezoekers kunnen momenteel niet rechtstreeks contact opnemen via de website. Er is een veilig, server-side contactformulier nodig dat gebruikmaakt van de bestaande Postfix/AWS SES infrastructuur op malandro.

## What Changes

- Nieuwe NixOS module `modules/mailer.nix` met PHP-FPM pool en nginx vhost `mailer.toorren.net`
- PHP contactformulier script volledig declaratief gegenereerd via `pkgs.writeTextFile`
- Configureerbare ontvangst-emailadressen per domein via NixOS module opties (`attrsOf str`)
- Vijf beveiligingslagen: nginx rate limiting, Origin whitelist, honeypot veld, self-hosted Cap (proof-of-work CAPTCHA) server-side validatie, fail2ban filter op 403-responses
- Self-hosted Cap i.p.v. Cloudflare Turnstile: nieuwe module `modules/cap.nix` (Cap-server + Valkey op malandro), geen externe captcha-afhankelijkheid meer
- Nieuw agenix secret `secrets/cap-mailer-secret.age` (Cap key-secret) i.p.v. de Turnstile secret
- `modules/nginx-wereldvanbegrip.nix` uitgebreid met contactformulier HTML (incl. `cap-widget`)
- `hosts/malandro/configuration.nix` importeert de nieuwe module(s)
- `secrets/secrets.nix` krijgt de nieuwe Cap secrets (`cap-admin-key`, `cap-mailer-secret`)

## Capabilities

### New Capabilities

- `contact-mailer`: NixOS module die een herbruikbare PHP-FPM contactformulier mailer biedt met configureerbare ontvangers per domein en gelaagde beveiliging

### Modified Capabilities

*(geen bestaande specs wijzigen)*

## Impact

- **Nieuw**: PHP-FPM draait voor het eerst als host-service op malandro (los van Docker containers)
- **Postfix**: geen wijzigingen; PHP `mail()` gebruikt de bestaande AWS SES relay transparant
- **Nginx**: nieuwe vhost `mailer.toorren.net`, rate limiting zone toegevoegd
- **Cap**: self-hosted Cap-server (`cap.toorren.net`) + Valkey als oci-containers; site-key eenmalig aan te maken in het Cap-dashboard; widget vereist op het formulier
- **Agenix**: nieuwe secrets `secrets/cap-admin-key.age` en `secrets/cap-mailer-secret.age` aan te maken en te versleutelen
