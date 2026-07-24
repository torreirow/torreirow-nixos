## 1. Build-brekende fouten oplossen

- [ ] 1.1 Verwijder de `karlapi` entry uit `flake.nix` (verwijder de nixosConfigurations.karlapi sectie die verwijst naar `./hosts/karlapi/configuration.nix`)
- [ ] 1.2 Verifieer met `nix flake check` dat de flake zonder fouten evalueert

## 2. Security: secrets uit git halen

- [ ] 2.1 Controleer of `secrets/authelia-*.txt` bestanden actief gebruikt worden door een lopende service (grep door modules/)
- [ ] 2.2 Voeg `secrets/*.txt` toe aan `.gitignore`
- [ ] 2.3 Verwijder de `.txt` bestanden uit git tracking met `git rm --cached secrets/*.txt`
- [ ] 2.4 Verplaats de hardcoded argon2id hashes uit `hosts/malandro/configuration.nix:439,447` naar een agenix-beheerd bestand (`secrets/authelia-users.age`)
- [ ] 2.5 Update `modules/claude.nix` — wijzig het secret-pad van `/tmp/claude.env` naar `/run/secrets/claude.env`

## 3. Configuratie-fouten corrigeren

- [ ] 3.1 Herstel typefout in `hosts/lobos/lobos-secrets.nix:40`: `update_latop` → `update_laptop`
- [ ] 3.2 Herstel typefout in `hosts/malandro/malandro-secrets.nix:28`: `update_latop` → `update_laptop`
- [ ] 3.3 Controleer via grep of `update_latop` nog ergens anders voorkomt in de repo
- [ ] 3.4 Corrigeer locale in `hosts/malandro/configuration.nix`: `"nl.UTF-8"` → `"nl_NL.UTF-8"`

## 4. Dode code en lege modules verwijderen

- [ ] 4.1 Verwijder of vul `modules/general-desktop.nix` (momenteel leeg; als het nergens echt gebruikt wordt, verwijder ook de import)
- [ ] 4.2 Verwijder `hosts/malandro.new/` directory (check eerst git log om te zien hoe recent dit is)
- [ ] 4.3 Verwijder `hosts/mealhada/` directory (ongebruikte host, niet in flake.nix)
- [ ] 4.4 Verwijder ongebruikte secret-definities uit `secrets/secrets.nix`: `castopod-admin-password`, `jitsi-*-password`, `documenso-env` (verifieer eerst dat ze nergens actief gebruikt worden)

## 5. Backup- en restbestanden opruimen

- [ ] 5.1 Verwijder `modules/monitoring/prometheus/alertmanager.nix.old`
- [ ] 5.2 Verwijder `modules/monitoring/prometheus/prometheus.nix.backup`
- [ ] 5.3 Verwijder `overlays/solidtime.nix.wouter`
- [ ] 5.4 Verwijder `hosts/lobos/programs.wouter`
- [ ] 5.5 Verwijder `credentials.2` uit de root
- [ ] 5.6 Verwijder of archiveer `modules/documenso.nix.disabled`

## 6. Kleine inconsistenties oplossen

- [ ] 6.1 Verwijder dubbele `system = "x86_64-linux"` definities in `flake.nix` (al gedefinieerd op toplevel, dubbel in host let-blocks)

## 7. Verificatie

- [ ] 7.1 Voer `nix flake check` uit en verifieer dat er geen fouten zijn
- [ ] 7.2 Voer `sudo nixos-rebuild dry-build --flake .#lobos` uit
- [ ] 7.3 Voer `sudo nixos-rebuild dry-build --flake .#malandro` uit
