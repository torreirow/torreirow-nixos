## 1. Voorbereiding

- [x] 1.1 Maak `pkgs/formrelay/` directory aan in de repo
- [x] 1.2 Schrijf `pkgs/formrelay/go.mod` met module naam `formrelay` en Go versie
- [ ] 1.3 Voeg agenix secret toe: encrypt hCaptcha secret key naar `secrets/hcaptcha-secret.age`
- [x] 1.4 Update `secrets/secrets.nix` met `hcaptcha-secret.age` entry

## 2. Go binary implementatie

- [x] 2.1 Schrijf `pkgs/formrelay/main.go`: HTTP server op configureerbare poort, lees config JSON bij opstarten
- [x] 2.2 Implementeer token lookup en Origin header validatie
- [x] 2.3 Implementeer hCaptcha server-side verificatie (POST naar api.hcaptcha.com/siteverify, 5s timeout)
- [x] 2.4 Implementeer honeypot check (`_gotcha` veld)
- [x] 2.5 Implementeer email verzending via localhost SMTP (poort 25, plain text)
- [x] 2.6 Implementeer CORS response headers per token
- [x] 2.7 Implementeer OPTIONS preflight handler
- [x] 2.8 Voeg `vendorHash` toe aan de Nix derivation (run `go mod vendor` en bereken hash)

## 3. NixOS module

- [x] 3.1 Schrijf `modules/formrelay.nix` met `services.formrelay` module opties (enable, port, hcaptchaSecretFile, fromAddress, forms)
- [x] 3.2 Voeg `pkgs/formrelay/default.nix` toe als `buildGoModule` derivation
- [x] 3.3 Implementeer config JSON generatie in de module via `pkgs.writeText` of `environment.etc`
- [x] 3.4 Schrijf systemd service unit in de module (User=formrelay, DynamicUser=true, ExecStart met --config en --hcaptcha-secret-file)
- [x] 3.5 Voeg nginx virtual host toe voor `forms.toorren.net` in de module (forceSSL, useACMEHost, proxyPass naar 127.0.0.1:8094)

## 4. Malandro integratie

- [x] 4.1 Importeer `modules/formrelay.nix` in `hosts/malandro/configuration.nix`
- [x] 4.2 Configureer `services.formrelay` met tokens voor de 4 sites (wereldvanbegrip.nl, boaz.toorren.net, noraly.toorren.net, cv-jolijn.toorren.net)
- [x] 4.3 Update `PORTS.md`: voeg port 8094 toe voor formrelay
- [ ] 4.4 Voer `sudo nixos-rebuild switch --flake .#malandro` uit en verifieer dat de service draait

## 5. DNS en certificaat

- [x] 5.1 Controleer of `forms.toorren.net` gedekt wordt door het bestaande wildcard ACME certificaat (`*.toorren.net`)
- [ ] 5.2 Voeg DNS A-record toe voor `forms.toorren.net` → malandro IP (of controleer of wildcard DNS al bestaat)

## 6. Verificatie

- [ ] 6.1 Test `/submit` endpoint met curl: geldige POST met echte hCaptcha token
- [ ] 6.2 Test spam bescherming: POST zonder hCaptcha, POST met verkeerde origin, POST met gevuld honeypot veld
- [ ] 6.3 Verifieer email aankomst in inbox voor elk geconfigureerd formulier
- [ ] 6.4 Verifieer CORS headers in browser (DevTools Network tab)
