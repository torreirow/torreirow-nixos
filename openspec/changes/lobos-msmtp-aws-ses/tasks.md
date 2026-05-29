## 1. Secret aanmaken

- [x] 1.1 Voeg `msmtp-password.age` toe aan `secrets/secrets.nix` met de juiste public keys (lobos + wtoorren)
- [ ] 1.2 Maak het encrypted secret aan: `agenix -e secrets/msmtp-password.age` (bevat alleen het AWS SES SMTP wachtwoord)

## 2. NixOS module aanmaken

- [x] 2.1 Maak `hosts/lobos/mail.nix` aan met `programs.msmtp` configuratie (account default, from lobos@toorren.net, AWS SES relay, passwordeval via agenix secret)
- [x] 2.2 Voeg `age.secrets.msmtp-password` configuratie toe aan de module
- [x] 2.3 Importeer `./mail.nix` in `hosts/lobos/configuration.nix`

## 3. Deployen en testen

- [ ] 3.1 `sudo nixos-rebuild switch --flake .#lobos`
- [ ] 3.2 Test: `echo "Test van lobos" | mail -s "msmtp test" wtoorren@toorren.net`
- [ ] 3.3 Controleer dat de ontvangen mail `From: lobos@toorren.net` heeft
