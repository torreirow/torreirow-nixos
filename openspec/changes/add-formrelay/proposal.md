## Why

De statische websites op malandro (wereldvanbegrip.nl, boaz.toorren.net, noraly.toorren.net, cv-jolijn.toorren.net) hebben geen backend en kunnen daardoor geen contactformulieren verwerken. Een externe dienst zoals Formspree is een onnodige afhankelijkheid terwijl de benodigde infrastructuur (nginx + postfix AWS SES relay) al aanwezig is.

## What Changes

- Nieuwe Go binary `formrelay` die als systemd service draait op malandro
- HTTP POST endpoint `/submit` voor AJAX contactformulierverwerking
- hCaptcha server-side verificatie (domein-gebonden spam bescherming)
- Multi-token routing: elke website krijgt een unieke token die mapt naar een ontvanger
- Nieuwe nginx virtual host `forms.toorren.net` als reverse proxy
- Nieuwe NixOS module `modules/formrelay.nix` met declaratieve configuratie
- agenix secret voor de hCaptcha secret key

## Capabilities

### New Capabilities

- `form-submission`: HTTP endpoint dat POST data ontvangt, valideert en doorstuurt als email via lokale postfix
- `form-token-routing`: multi-token configuratie waarbij elke token een ontvanger, toegestane origins en naam definieert
- `form-spam-protection`: hCaptcha verificatie + honeypot veld + Origin header check
- `formrelay-nixos-module`: NixOS module die de service declaratief configureert inclusief nginx virtual host

### Modified Capabilities

## Impact

- **Nieuw bestand**: `modules/formrelay.nix` — NixOS module
- **Nieuw bestand**: Go broncode voor de formrelay binary (via `buildGoModule` of inline derivation)
- **Wijziging**: `hosts/malandro/configuration.nix` — import van nieuwe module
- **Nieuw secret**: `secrets/hcaptcha-secret.age` — hCaptcha server-side secret key
- **Nieuwe DNS**: `forms.toorren.net` moet wijzen naar malandro
- **Nieuwe ACME**: wildcard `*.toorren.net` dekt `forms.toorren.net` al af
- **Afhankelijkheden**: postfix module (al aanwezig), nginx module (al aanwezig), agenix (al aanwezig)
