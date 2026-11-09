# rbw-status-label Specification

## Purpose
In de tmux-statusbar zien welk rbw-profiel (Bitwarden-kluis) actief is en of die ontgrendeld is,
zodat duidelijk is uit welke kluis wachtwoorden en ssh-sleutels komen.

## Requirements

### Requirement: Profiel-label weergave in tmux statusbar
De tmux statusbar SHALL een rbw-indicator tonen in het formaat `<icon><label>`, waarbij `<icon>` het
lock-symbool is en `<label>` afgeleid wordt uit het actieve profiel via een geconfigureerde mapping.
Het actieve profiel SHALL `$RBW_PROFILE` zijn als die gezet is, en anders de inhoud van
`~/.config/rbw/active-profile`.

#### Scenario: Unlocked met bekend profiel
- **WHEN** `rbw unlocked` slaagt (exit 0) en het actieve profiel overeenkomt met een geconfigureerd profiel (bv. "technative")
- **THEN** toont de statusbar `🔓TN`

#### Scenario: Locked met bekend profiel
- **WHEN** `rbw unlocked` faalt (exit non-zero) en het actieve profiel overeenkomt met een geconfigureerd profiel
- **THEN** toont de statusbar `🔒TN`

#### Scenario: Unlocked zonder profiel of onbekend profiel
- **WHEN** `rbw unlocked` slaagt en er geen actief profiel is of het niet voorkomt in de mapping
- **THEN** toont de statusbar `🔓WT`

#### Scenario: Locked zonder profiel of onbekend profiel
- **WHEN** `rbw unlocked` faalt en er geen actief profiel is of het niet voorkomt in de mapping
- **THEN** toont de statusbar `🔒WT`

#### Scenario: Profiel gekozen met rbwsel
- **WHEN** `rbwsel` het profiel `technative` in `~/.config/rbw/active-profile` zet en de tmux-server geen `RBW_PROFILE` kent
- **THEN** toont de statusbar na de volgende refresh het label `TN`

### Requirement: Nix-declaratieve profielmapping
De profielmapping SHALL als Nix attrset gedefinieerd worden bovenaan `home/tmux.nix`, zodat nieuwe profielen op één plek toegevoegd kunnen worden zonder de shell-logica te wijzigen.

#### Scenario: Nieuw profiel toevoegen
- **WHEN** een entry toegevoegd wordt aan `rbwProfiles` (bv. `"personal" = "PR"`)
- **THEN** genereert de Nix-build automatisch een bijgewerkte `case`-statement die het nieuwe profiel herkent
