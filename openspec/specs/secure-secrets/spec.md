# secure-secrets Specification

## Purpose
Geen plaintext geheimen in git: secrets staan versleuteld als agenix-bestanden en alleen
versleutelde bestanden en de recipient-regels horen in `secrets/`.

## Requirements

### Requirement: Alle secrets worden beheerd via agenix
De NixOS configuratie SHALL geen plaintext secrets bevatten in git-getrackte bestanden. Alle secrets MUST worden versleuteld met agenix (`.age` bestanden) en worden ontsleuteld via `age.secrets` in de NixOS configuratie.

#### Scenario: Geen plaintext secrets in git
- **WHEN** `git ls-files secrets/` wordt uitgevoerd
- **THEN** worden alleen `.age` bestanden en `secrets.nix` getoond, geen `.txt` of andere plaintext bestanden

#### Scenario: Authelia wachtwoordhashes niet hardcoded
- **WHEN** `grep -r 'argon2id' hosts/` wordt uitgevoerd
- **THEN** worden geen hashes gevonden in `.nix` configuratiebestanden
