## ADDED Requirements

### Requirement: Eigen domeinlijsten worden uit bestanden geladen
Eigen denylist-groepen SHALL hun domeinen uit platte tekstbestanden (hosts-formaat) laden i.p.v.
inline in de Nix-config. De baseline-bestanden SHALL in de repo staan (`modules/blocky/lists/`) en
in git versiebeheerd zijn.

#### Scenario: Baseline-domein geblokkeerd
- **WHEN** een domein in de baseline-`.txt` van een actieve groep staat en blocky draait
- **THEN** SHALL blocky dat domein blokkeren voor de clients van die groep

#### Scenario: Geen domeinen inline in Nix
- **WHEN** de blocky-module wordt bekeken
- **THEN** SHALL een eigen domeinlijst naar een bestand verwijzen, niet als inline YAML-blok staan

### Requirement: Elke groep heeft een mutabel overlay-bestand naast de baseline
Elke eigen groep SHALL naast de baseline een mutabel overlay-bestand hebben op
`/data/external/blocky/denylists.d/<groep>.txt` (en een allowlist-overlay-bestand op
`/data/external/blocky/allowlists.d/<groep>.txt`). blocky SHALL de bronnen van een groep
samenvoegen. (blocky accepteert als bron alleen een bestand, geen directory of glob.) De
overlay-bestanden SHALL bestaan (leeg aangemaakt via tmpfiles, `root:root 0644`, bewerkbaar met
`sudo`) en door blocky gelezen worden onder `DynamicUser` + `ProtectSystem=strict`.

#### Scenario: Overlay voegt een blokkade toe zonder rebuild
- **WHEN** een beheerder een domein in de denylist-overlay van een groep zet en de lijsten herlaadt
- **THEN** SHALL blocky dat domein blokkeren zonder `nixos-rebuild` of service-herstart

#### Scenario: Allowlist-overlay geeft live vrij
- **WHEN** een beheerder een domein in de allowlist-overlay van een groep zet en herlaadt
- **THEN** SHALL dat domein weer resolveren voor die groep

#### Scenario: Baseline overleeft verlies van de overlay
- **WHEN** het overlay-bestand leeg is of ontbreekt
- **THEN** SHALL de baseline uit git na een rebuild gewoon weer actief zijn en SHALL blocky starten

### Requirement: Lijsten live herlaadbaar via een helper
Er SHALL een `blocky-refresh`-commando zijn dat `POST http://127.0.0.1:4000/api/lists/refresh`
aanroept en de HTTP-status toont (geen stille fout).

#### Scenario: Refresh activeert overlay-wijzigingen
- **WHEN** een beheerder na een overlay-wijziging `blocky-refresh` draait
- **THEN** SHALL blocky alle bronnen opnieuw inlezen en SHALL het commando slagen (of de foutstatus tonen)
