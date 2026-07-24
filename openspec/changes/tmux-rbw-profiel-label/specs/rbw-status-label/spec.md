## ADDED Requirements

### Requirement: Profiel-label weergave in tmux statusbar
De tmux statusbar SHALL een rbw-indicator tonen in het formaat `<icon> bw <label>`, waarbij `<icon>` het lock-symbool is en `<label>` afgeleid wordt uit `$RBW_PROFILE` via een geconfigureerde mapping.

#### Scenario: Unlocked met bekend profiel
- **WHEN** `rbw unlocked` slaagt (exit 0) en `$RBW_PROFILE` overeenkomt met een geconfigureerd profiel (bv. "technative")
- **THEN** toont de statusbar `🔓 bw TN`

#### Scenario: Locked met bekend profiel
- **WHEN** `rbw unlocked` faalt (exit non-zero) en `$RBW_PROFILE` overeenkomt met een geconfigureerd profiel
- **THEN** toont de statusbar `🔒 bw TN`

#### Scenario: Unlocked zonder profiel of onbekend profiel
- **WHEN** `rbw unlocked` slaagt en `$RBW_PROFILE` leeg is of niet voorkomt in de mapping
- **THEN** toont de statusbar `🔓 bw WT`

#### Scenario: Locked zonder profiel of onbekend profiel
- **WHEN** `rbw unlocked` faalt en `$RBW_PROFILE` leeg is of niet voorkomt in de mapping
- **THEN** toont de statusbar `🔒 bw WT`

### Requirement: Nix-declaratieve profielmapping
De profielmapping SHALL als Nix attrset gedefinieerd worden bovenaan `home/tmux.nix`, zodat nieuwe profielen op één plek toegevoegd kunnen worden zonder de shell-logica te wijzigen.

#### Scenario: Nieuw profiel toevoegen
- **WHEN** een entry toegevoegd wordt aan `rbwProfiles` (bv. `"personal" = "PR"`)
- **THEN** genereert de Nix-build automatisch een bijgewerkte `case`-statement die het nieuwe profiel herkent
