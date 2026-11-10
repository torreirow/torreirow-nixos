## Why

De NixOS configuratie bevat build-brekende fouten, beveiligingsrisico's (plaintext secrets in git) en dode code die de repo moeilijk onderhoudbaar maakt. Een gerichte opruimactie lost deze problemen op voordat ze grotere schade aanrichten.

## What Changes

- Verwijder de referentie naar de niet-bestaande `karlapi` host uit `flake.nix`
- Verplaats plaintext Authelia `.txt` secretbestanden buiten git (of versleutel ze met agenix)
- Verplaats hardcoded argon2id wachtwoordhashes in `malandro/configuration.nix` naar agenix-beheerde secrets
- Corrigeer het secret-pad in `modules/claude.nix` van `/tmp/claude.env` naar `/run/secrets/claude.env`
- Herstel de typefout `update_latop` → `update_laptop` in `lobos-secrets.nix` en `malandro-secrets.nix`
- Corrigeer locale `"nl.UTF-8"` → `"nl_NL.UTF-8"` in `hosts/malandro/configuration.nix`
- Verwijder dode directories `hosts/malandro.new/` en `hosts/mealhada/`
- Verwijder of vul de lege module `modules/general-desktop.nix`
- Verwijder of archiveer ongebruikte secret-definities (`castopod-admin-password`, `jitsi-*-password`, `documenso-env`)
- Verwijder backup- en restbestanden (`*.old`, `*.backup`, `*.wouter`, `credentials.2`, `documenso.nix.disabled`)
- Verwijder dubbele `system = "x86_64-linux"` definities in `flake.nix`

## Capabilities

### New Capabilities

- `secure-secrets`: Alle secrets worden beheerd via agenix, geen plaintext in git

### Modified Capabilities

_Geen spec-level gedragswijzigingen — alleen configuratie en opruim._

## Impact

- `flake.nix` — karlapi-entry verwijderd, dubbele system-definitie opgeruimd
- `secrets/` — plaintext `.txt` bestanden verwijderd of versleuteld
- `hosts/malandro/configuration.nix` — hardcoded hashes vervangen door agenix secret-paden
- `modules/claude.nix` — secret-pad aangepast naar `/run/secrets/`
- `hosts/lobos/lobos-secrets.nix` en `hosts/malandro/malandro-secrets.nix` — typo hersteld
- `hosts/malandro/configuration.nix` — locale gecorrigeerd
- `hosts/malandro.new/`, `hosts/mealhada/` — verwijderd
- `modules/general-desktop.nix` — verwijderd of gevuld
- `secrets/secrets.nix` — ongebruikte secret-sleutels verwijderd
- Diverse backup-/restbestanden — verwijderd
