## Context

wereldvanbegrip.nl draait als statische Hugo site op malandro achter nginx. Malandro heeft al Postfix geconfigureerd als AWS SES relay (`modules/postfix.nix`). PHP-FPM draait momenteel niet op malandro — InvoicePlane gebruikt Docker. Het patroon voor PHP-FPM en nginx modules is beschikbaar als referentie in `modules/invoiceplane.nix` en `modules/nginx-wereldvanbegrip.nix`.

## Goals / Non-Goals

**Goals:**
- Één herbruikbare NixOS module voor contactformulier-verwerking
- Volledig declaratief: geen handmatig aangemaakte bestanden buiten Nix
- Configureerbaar per domein via module opties (toekomstige sites kunnen worden toegevoegd)
- Vijf beveiligingslagen, volledig op eigen infra (self-hosted Cap i.p.v. Cloudflare Turnstile)

**Non-Goals:**
- Opslaan van formuliersubmissies in een database
- Bevestigingsmail naar de indiener
- JavaScript-gebaseerde (fetch/XHR) formuliersubmissie — traditionele form POST volstaat

## Decisions

### PHP-FPM op de host in plaats van Docker

**Keuze:** PHP-FPM als NixOS systemd service, niet als Docker container.

**Reden:** De gebruiker wil maximaal NixOS-idiomatisch. Docker voegt een extra abstractielaag toe die niet nodig is voor een eenvoudig PHP script. PHP-FPM op de host gebruikt dezelfde Postfix relay transparant via `mail()` zonder extra netwerkconfiguratie.

**Alternatief overwogen:** Een kleine Go-binary als systemd service. Afgewezen omdat het geen bestaand patroon in de repo heeft en meer code vereist voor hetzelfde resultaat.

### Gedeeld endpoint op een eigen vhost (`mailer.toorren.net`)

**Keuze:** Eén nginx vhost `mailer.toorren.net` met `/send` endpoint, gedeeld door alle geconfigureerde domeinen.

**Reden:** Eén PHP-FPM pool, één module, nul duplicatie. Domeindistributie wordt afgehandeld door de Origin header check in PHP, niet door infrastructuurduplicatie.

**Alternatief overwogen:** Per-site PHP endpoints (bijv. `wereldvanbegrip.nl/send.php`). Afgewezen omdat dit PHP-FPM configuratie per nginx-module vereist en duplicatie introduceert.

### PHP script gegenereerd via `pkgs.writeTextFile`

**Keuze:** Het PHP script wordt gegenereerd als Nix derivation en via een symlink naar `/var/www/mailer/` geplaatst.

**Reden:** Volledig declaratief, geen handmatig beheerde bestanden. De inhoud van het script is traceerbaar via git. Volgt het principe van andere gegenereerde configuratiebestanden in NixOS.

### Self-hosted Cap i.p.v. Cloudflare Turnstile

**Keuze:** CAPTCHA-validatie via een self-hosted Cap-instance (`modules/cap.nix`: Cap-server + Valkey op malandro). De key-secret staat als `secrets/cap-mailer-secret.age`, ontsleuteld naar een pad via `age.secrets`; het PHP script doet een JSON siteverify-call (`{"secret","token"}`) naar `${capBaseUrl}/${capSiteKey}/siteverify`.

**Reden:** Geen externe (Cloudflare) afhankelijkheid meer — proof-of-work + instrumentatie, privacy-first, volledig op eigen infra (consistent met de rest van de repo). Het secret wordt uit een bestand gelezen (niet via een environment variable) zodat het niet in de Nix store belandt. Kanttekening: de Cap site-key/secret worden eenmalig via het Cap-dashboard aangemaakt (niet declaratief).

### `mail()` via Postfix — geen directe SMTP in PHP

**Keuze:** PHP gebruikt de standaard `mail()` functie die via de lokale MTA (Postfix) verstuurt.

**Reden:** Postfix met AWS SES relay draait al en werkt. Directe SMTP in PHP (PHPMailer/SwiftMailer) zou een extra dependency en SMTP-credentials in PHP vereisen. De bestaande relay is de eenvoudigste en veiligste weg.

## Risks / Trade-offs

- **PHP-FPM voor het eerst op malandro** → Nginx configuratiefouten in de nieuwe PHP location kunnen andere vhosts raken. Mitigation: dry-build testen voor deploy.
- **Origin header is spoofbaar** → Dit is een bekende beperking. Mitigation: de Cap-token is de primaire niet-spoofbare beschermingslaag; Origin is defense-in-depth.
- **Cap vereist eenmalige dashboard-actie** → Site-key/secret aanmaken is handmatig (Cap kent geen declaratieve key-provisioning). Mitigation: gedocumenteerd als expliciete taak in tasks.md.
- **Postfix downtime = geen formuliermail** → Postfix is een enkel punt van falen voor mailaflevering. Mitigation: buiten scope; Postfix is al productie-kritisch voor andere services.

## Migration Plan

1. Cap site-key en key-secret aanmaken in het self-hosted Cap-dashboard
2. Secret versleutelen als `secrets/cap-mailer-secret.age`
3. `modules/mailer.nix` aanmaken
4. Module importeren en configureren in `hosts/malandro/configuration.nix`
5. Contactformulier HTML toevoegen aan `modules/nginx-wereldvanbegrip.nix`
6. `sudo nixos-rebuild switch --flake .#malandro` uitvoeren
7. Formulier testen op wereldvanbegrip.nl

**Rollback:** Module-import verwijderen uit `configuration.nix` en opnieuw deployen. PHP-FPM pool en nginx vhost worden verwijderd.

## Open Questions

- Welk specifiek HTML-formulier template gewenst op wereldvanbegrip.nl? (velden, styling, bevestigingstekst)
- Wordt een ACME certificaat aangevraagd voor `mailer.toorren.net`, of valt het onder het bestaande wildcard cert voor `*.toorren.net`?
