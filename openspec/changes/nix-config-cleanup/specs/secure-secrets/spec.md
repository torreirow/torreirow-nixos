## ADDED Requirements

### Requirement: Alle secrets worden beheerd via agenix
De NixOS configuratie SHALL geen plaintext secrets bevatten in git-getrackte bestanden. Alle secrets MUST worden versleuteld met agenix (`.age` bestanden) en worden ontsleuteld via `age.secrets` in de NixOS configuratie.

#### Scenario: Geen plaintext secrets in git
- **WHEN** `git ls-files secrets/` wordt uitgevoerd
- **THEN** worden alleen `.age` bestanden en `secrets.nix` getoond, geen `.txt` of andere plaintext bestanden

#### Scenario: Authelia wachtwoordhashes niet hardcoded
- **WHEN** `grep -r 'argon2id' hosts/` wordt uitgevoerd
- **THEN** worden geen hashes gevonden in `.nix` configuratiebestanden

### Requirement: Secrets staan op veilige, niet-world-readable locaties
Agenix secrets MUST worden geplaatst op paden buiten `/tmp`. Het aanbevolen pad is `/run/secrets/<naam>` via de `age.secrets.<naam>.path` optie.

#### Scenario: claude.nix gebruikt beveiligd pad
- **WHEN** de claude agenix secret wordt gedecrypteerd
- **THEN** staat het bestand op `/run/secrets/claude.env` met restrictieve permissies (niet world-readable)

#### Scenario: Secret-pad overleeft reboot
- **WHEN** het systeem herstart
- **THEN** wordt het secret opnieuw aangemaakt door agenix op het geconfigureerde pad

### Requirement: Ongebruikte secret-definities worden verwijderd
Secrets die gedefinieerd zijn in `secrets/secrets.nix` maar geen actieve module hebben MUST worden verwijderd om de configuratie consistent te houden.

#### Scenario: Geen wees-secrets in secrets.nix
- **WHEN** `secrets/secrets.nix` wordt gereviewd
- **THEN** heeft elke gedefinieerde secret een corresponderende actieve module of configuratieregel die ernaar verwijst
