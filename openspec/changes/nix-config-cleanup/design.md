## Context

De torreirow-nixos flake bevat na een review een reeks problemen variërend van build-brekende fouten (ontbrekende host) tot beveiligingsrisico's (plaintext secrets in git) en dode code. De problemen zijn gecategoriseerd in vier prioriteitsklassen: ERROR, SECURITY, WARNING en INFO.

Huidige staat:
- `flake.nix` verwijst naar `hosts/karlapi` dat niet bestaat → `nix flake check` faalt
- Plaintext Authelia secrets (`.txt`) zijn getrackt in git
- Hardcoded argon2id hashes staan in `malandro/configuration.nix`
- `/tmp/claude.env` is world-readable en niet persistent
- Typo `update_latop` in twee secrets-bestanden
- Locale misconfiguratie op malandro
- Dode directories en backup-bestanden vervuilen de repo

## Goals / Non-Goals

**Goals:**
- Flake bouwt zonder fouten (`nix flake check` slaagt)
- Geen plaintext secrets getrackt in git
- Alle secrets lopen via agenix
- Repo is vrij van dode code, backup-bestanden en ongebruikte definities
- Configuratie-inconsistenties zijn gecorrigeerd

**Non-Goals:**
- Functionele wijzigingen aan services
- Migratie van bestaande agenix-secrets naar een andere tool
- Opruimen van `_archive/` directory
- Refactoring van modulearchitectuur

## Decisions

### 1. Karlapi: verwijder de entry uit flake.nix
De hosts/karlapi directory bestaat niet en er is geen context dat dit systeem actief is. De entry wordt verwijderd uit `flake.nix`. Als karlapi ooit nodig is, wordt het opnieuw opgezet vanuit scratch.

**Alternatief overwogen:** Lege placeholder aanmaken — verworpen omdat een lege host geen waarde heeft en verwarring geeft.

### 2. Authelia plaintext .txt bestanden: verwijder uit git
De `.txt` bestanden bevatten plaintext secrets die al in de git-geschiedenis zitten. De bestanden worden uit tracking gehaald (`.gitignore`) en vervangen door `.age` bestanden. Git-geschiedenis saneren valt buiten scope van deze taak (aparte actie vereist).

**Alternatief overwogen:** git filter-repo om history te saneren — bewust uitgesloten als separate actie; history-sanering vereist coördinatie met remote.

### 3. Argon2id hashes: verplaats naar agenix users-file
De hashes worden verplaatst naar een agenix-beheerd bestand (bijv. `secrets/authelia-users.age`) dat al gebruikt wordt door de authelia module. In `malandro/configuration.nix` wordt verwezen naar het secret-pad.

### 4. claude.nix: wijzig pad naar /run/secrets/
`/tmp` is world-readable en wordt geleegd bij reboot. Agenix ondersteunt expliciet pad-instelling via `age.secrets.<name>.path`. Pad wordt `/run/secrets/claude.env`.

### 5. Dode directories: verwijder zonder archiveren
`hosts/malandro.new/` is een werkkopie, `hosts/mealhada/` is een ongebruikte host. Beide worden verwijderd. Git-history bewaart de inhoud indien nodig.

### 6. Backup-bestanden: verwijderen
Bestanden als `*.old`, `*.backup`, `*.wouter` horen in git-history, niet in de werkdirectory.

## Risks / Trade-offs

- [Authelia .txt bestanden in git-history] → Risico blijft bestaan totdat history gesaneerd wordt. Mitigation: bestanden uit tracking halen zodat ze niet verder verspreid worden; history-sanering als aparte geplande actie.
- [update_latop typo fix] → Als de secret-naam ergens anders nog gebruikt wordt (bijv. in een script buiten de repo), breekt dat. Mitigation: grep door de gehele repo voor gebruik van de naam.
- [Verwijderen malandro.new/] → Als dit een in-progress migratie was, gaat werk verloren. Mitigation: controleer git log voor recentheid voordat je verwijdert.

## Migration Plan

1. Fix de build-brekende error (karlapi) als eerste
2. Pas security-fixes toe (secrets uit git, claude.nix pad)
3. Pas warnings toe (typo, locale, lege module)
4. Verwijder dode code en backup-bestanden
5. Voer `nix flake check` uit na elke stap om regressies te voorkomen
6. Sluit af met `sudo nixos-rebuild dry-build --flake .#lobos` en `.#malandro`

**Rollback:** Elke stap is een aparte git commit, dus rollback per stap via `git revert`.

## Open Questions

- Moeten de Authelia `.txt` bestanden actief gebruikt worden door een lopende service, of zijn ze verouderd? → Controleer vóór verwijdering.
- Is `hosts/mealhada/` een geplande toekomstige host of een verlaten experiment?
