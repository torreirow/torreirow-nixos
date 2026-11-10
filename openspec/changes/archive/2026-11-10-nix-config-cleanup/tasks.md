## 1. Build-brekende fouten oplossen

- [x] 1.1 Verwijder de `karlapi` entry uit `flake.nix` (verwijder de nixosConfigurations.karlapi sectie die verwijst naar `./hosts/karlapi/configuration.nix`)
- [x] 1.2 Verifieer met `nix flake check` dat de flake zonder fouten evalueert

## 2. Security: secrets uit git halen

- [x] 2.1 Controleer of `secrets/authelia-*.txt` bestanden actief gebruikt worden door een lopende service (grep door modules/)
- [x] 2.2 Voeg `secrets/*.txt` toe aan `.gitignore`
- [x] 2.3 Verwijder de `.txt` bestanden uit git tracking met `git rm --cached secrets/*.txt`
- [x] 2.4 Verplaats de hardcoded argon2id hashes uit `hosts/malandro/configuration.nix:439,447` naar een agenix-beheerd bestand (`secrets/authelia-users.age`)
- [x] 2.5 ~~Update `modules/claude.nix` — wijzig het secret-pad van `/tmp/claude.env` naar `/run/secrets/claude.env`~~ Geschrapt (2026-11-10): onduidelijk wat het pad leest; bewust niet gewijzigd

## 3. Configuratie-fouten corrigeren

- [x] 3.1 Herstel typefout in `hosts/lobos/lobos-secrets.nix:40`: `update_latop` → `update_laptop`
- [x] 3.2 Herstel typefout in `hosts/malandro/malandro-secrets.nix:28`: `update_latop` → `update_laptop`
- [x] 3.3 Controleer via grep of `update_latop` nog ergens anders voorkomt in de repo
- [x] 3.4 Corrigeer locale in `hosts/malandro/configuration.nix`: `"nl.UTF-8"` → `"nl_NL.UTF-8"`

## 4. Dode code en lege modules verwijderen

- [x] 4.1 Verwijder of vul `modules/general-desktop.nix` (momenteel leeg; als het nergens echt gebruikt wordt, verwijder ook de import)
- [x] 4.2 Verwijder `hosts/malandro.new/` directory (check eerst git log om te zien hoe recent dit is)
- [x] 4.3 Verwijder `hosts/mealhada/` directory (ongebruikte host, niet in flake.nix)
- [x] 4.4 Verwijder ongebruikte secret-definities uit `secrets/secrets.nix`: `castopod-admin-password`, `jitsi-*-password`, `documenso-env` (verifieer eerst dat ze nergens actief gebruikt worden). Stand 2026-11-10: jitsi en documenso al weg; `castopod-admin-password` blijft bewust (bewaard admin-wachtwoord van de draaiende Castopod)

## 5. Backup- en restbestanden opruimen

- [x] 5.1 Verwijder `modules/monitoring/prometheus/alertmanager.nix.old`
- [x] 5.2 Verwijder `modules/monitoring/prometheus/prometheus.nix.backup`
- [x] 5.3 Verwijder `overlays/solidtime.nix.wouter`
- [x] 5.4 Verwijder `hosts/lobos/programs.wouter`
- [x] 5.5 Verwijder `credentials.2` uit de root
- [x] 5.6 Verwijder of archiveer `modules/documenso.nix.disabled`

## 6. Kleine inconsistenties oplossen

- [x] 6.1 Verwijder dubbele `system = "x86_64-linux"` definities in `flake.nix` (al gedefinieerd op toplevel, dubbel in host let-blocks)

## 7. Verificatie

- [x] 7.1 Voer `nix flake check` uit en verifieer dat er geen fouten zijn
- [x] 7.2 Voer `sudo nixos-rebuild dry-build --flake .#lobos` uit
- [x] 7.3 Voer `sudo nixos-rebuild dry-build --flake .#malandro` uit

## Stand 2026-11-10

Groep 2, 3.1–3.3 en 5 (behalve 5.4) waren al buiten deze change om gedaan (o.a. bean
`nixos-38kf`, gelekte secrets). Nu gedaan: karlapi uit de flake, malandro.new/mealhada/
programs.wouter/general-desktop.nix weg, dubbele `system`-definities weg, locale `nl_NL.UTF-8`.
Bewijs: de drvPaths van alle 15 outputs (3 hosts, 4 home-configs, 8 checks) zijn identiek vóór en
na, behalve malandro door de locale; `nix flake check --no-build` slaagt; malandro bouwt.
De delta-spec is ingekort tot wat echt geldt: de eisen over `/run/secrets/claude.env` en over
wees-secrets zijn eruit, omdat die bewust niet zijn doorgevoerd.
