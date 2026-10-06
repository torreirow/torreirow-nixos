## 1. Module

- [x] 1.1 `modules/grainwork.nix`: opties, certificaat, agenix-secrets, Pocket ID + vhost met setup-slot, oauth2-proxy + site-vhost met publieke locaties, assertions
- [x] 1.2 `PORTS.md`: 8098 Pocket ID, 8099 oauth2-proxy

## 2. Secrets

- [x] 2.1 `secrets/secrets.nix`: recipients voor de vier `grainwork-*.age`-bestanden
- [x] 2.2 `grainwork-pocket-id-encryption-key.age` en `grainwork-oauth2-proxy-cookie.age` willekeurig genereren (waarden nooit tonen)

## 3. malandro

- [x] 3.1 Module importeren in `hosts/malandro/configuration.nix`; schakelaars uit met uitleg welke handmatige stap ze vrijgeeft

## 4. Tests

- [x] 4.1 VM-test `modules/grainwork_vmtest.nix` als `checks.x86_64-linux.grainwork` in `flake.nix`
- [x] 4.2 Eval-test `modules/grainwork_test.py` op de malandro-config met alle fasen aan
- [x] 4.3 malandro-config bouwt (`nix build .#nixosConfigurations.malandro.config.system.build.toplevel`)

## 5. Documentatie en afronding

- [x] 5.1 Stappenplan voor de beheerder in de design en de module-header
- [x] 5.2 CHANGELOG onder `## NEXT VERSION`
