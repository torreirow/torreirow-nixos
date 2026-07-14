## 1. Cloudflare Turnstile inrichten (handmatig)

- [ ] 1.1 Maak een nieuw Turnstile widget aan in het Cloudflare dashboard voor `wereldvanbegrip.nl`
- [ ] 1.2 Kopieer de **Site Key** (publiek, voor de HTML) en de **Secret Key** (privé, voor PHP)
- [ ] 1.3 Versleutel de secret key: `agenix -e secrets/turnstile-secret.age`
- [x] 1.4 Voeg het nieuwe secret toe aan `secrets/secrets.nix` met de juiste public keys

## 2. NixOS module `modules/mailer.nix` aanmaken

- [x] 2.1 Maak `modules/mailer.nix` aan met NixOS module opties: `enable`, `recipients` (attrsOf str), `turnstileSecretFile`
- [x] 2.2 Voeg PHP-FPM pool toe aan de module (volg patroon van `modules/invoiceplane.nix`): minimale pool, user=nginx, php83 met curl en openssl extensies
- [x] 2.3 Genereer het PHP contactformulier script via `pkgs.writeTextFile` met de volgende logica:
  - Laad recipients config uit een gegenereerd JSON-bestand (via `pkgs.writeText`)
  - Valideer Origin/Referer header tegen geconfigureerde domeinen (403 bij mismatch)
  - Controleer honeypot veld `website` (stil negeren als ingevuld)
  - Valideer Cloudflare Turnstile token via `file_get_contents` naar de Turnstile API
  - Verstuur email via `mail()` naar het geconfigureerde ontvangst-emailadres
  - Redirect terug naar de referrer met een succesparameter
- [x] 2.4 Voeg nginx vhost `mailer.toorren.net` toe aan de module:
  - `useACMEHost = "toorren.net"` (wildcard cert)
  - `forceSSL = true`
  - Rate limiting zone: `limit_req_zone $binary_remote_addr zone=contactform:10m rate=5r/m`
  - POST-only location `/send` met rate limiting (`limit_req zone=contactform burst=3 nodelay`)
  - FastCGI doorsturen naar PHP-FPM socket
- [x] 2.5 Voeg `systemd.tmpfiles.rules` toe voor `/var/www/mailer` directory

## 3. Module integreren in malandro

- [x] 3.1 Importeer `modules/mailer.nix` in `hosts/malandro/configuration.nix`
- [x] 3.2 Configureer de module in `configuration.nix`:
  ```nix
  services.contactMailer = {
    enable = true;
    recipients = { "wereldvanbegrip.nl" = "wereldvanbegrip@toorren.net"; };
    turnstileSecretFile = config.age.secrets.turnstile-secret.path;
  };
  ```
- [x] 3.3 Voeg het agenix secret toe aan de malandro host configuratie

## 4. Contactformulier HTML toevoegen

- [x] 4.1 Voeg een contactformulier sectie toe aan `modules/nginx-wereldvanbegrip.nix` of de Hugo site bronbestanden:
  - Velden: `naam`, `email`, `bericht`
  - Honeypot veld `website` (verborgen via CSS, niet `display:none` voor screenreaders)
  - Cloudflare Turnstile widget met de Site Key uit stap 1.2
  - `action="https://mailer.toorren.net/send"` en `method="POST"`

## 5. Testen en deployen

- [x] 5.1 Voer een dry-build uit: `sudo nixos-rebuild dry-build --flake .#malandro --show-trace`
- [x] 5.2 Deploy naar malandro: `sudo nixos-rebuild switch --flake .#malandro`
- [x] 5.3 Controleer PHP-FPM pool status: `systemctl status phpfpm-mailer.service`
- [ ] 5.4 Test het formulier op wereldvanbegrip.nl en verifieer email aankomst op `wereldvanbegrip@toorren.net`
- [ ] 5.5 Test beveiligingslagen: rate limiting (>5 requests/min), Origin mismatch (403), honeypot (stille negatie)
