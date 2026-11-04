## ADDED Requirements

### Requirement: Eén profiel, twee ingangen
Het systeem SHALL het home-manager-profiel wtoorren-admin aanbieden als NixOS-module
(`toorren.admin.enable`) en als standalone `homeConfigurations."wtoorren@admin"`. Beide MUST
dezelfde profielcode en dezelfde HM-optie `toorren.admin.aws.enable` gebruiken.

#### Scenario: NixOS-host
- **WHEN** een NixOS-host `toorren.admin.enable = true` zet
- **THEN** krijgt `wtoorren` via home-manager zsh, tmux, nixvim en de rbw-configs

#### Scenario: Niet-NixOS-host
- **WHEN** `nix build .#homeConfigurations."wtoorren@admin".activationPackage` draait zonder `--impure`
- **THEN** slaagt de build

### Requirement: Beheeraccount
Met `toorren.admin.createUser` (default true) MUST de module `users.users.wtoorren` aanmaken met
wheel, networkmanager (als NetworkManager aan staat), de ssh-sleutel `wtoorren` en zsh. sudo
SHALL een wachtwoord blijven vragen.

#### Scenario: mpenzi
- **WHEN** mpenzi wordt geëvalueerd
- **THEN** heeft `wtoorren` wheel, networkmanager en de sleutel, en definieert alleen de module het account

### Requirement: SSH-agent per sessie
De login-shell MUST `SSH_AUTH_SOCK` naar de rbw-agent zetten als `SSH_CONNECTION` leeg is, en
het anders ongemoeid laten.

#### Scenario: Via ssh ingelogd
- **WHEN** zsh start met `SSH_CONNECTION` gezet
- **THEN** wijst `SSH_AUTH_SOCK` niet naar de rbw-agent

### Requirement: AWS-shell alleen met credentials
bmc en race MUST altijd geïnstalleerd zijn. De zsh-functie `bmc` en de aliassen `bmcp`,
`aws-switch`, `tfplan`, `tfapply`, `tfbackend` MUST alleen bestaan als op runtime
`~/.aws/credentials` bestaat.

#### Scenario: Zonder credentials
- **WHEN** `~/.aws/credentials` ontbreekt
- **THEN** is `bmc` in zsh geen functie

#### Scenario: Met credentials
- **WHEN** `~/.aws/credentials` bestaat
- **THEN** is `bmc` in zsh een functie

### Requirement: AWS-config achter een schakelaar
`~/.aws/config` MUST alleen gegenereerd worden bij `toorren.admin.aws.enable = true`; dat vraagt
`--impure`.

#### Scenario: Standaard uit
- **WHEN** het profiel aan staat zonder aws.enable
- **THEN** staat er geen `.aws/config` in de HM-generatie

#### Scenario: Aan
- **WHEN** aws.enable aan staat en met `--impure` wordt geëvalueerd
- **THEN** bevat de HM-generatie `.aws/config`

### Requirement: Headless bmc-MFA
Het profiel MUST `~/.config/bmc/config.json` beheren met MFA aan, een `totp_script` met `rbw code`
en een copy-commando dat zonder Wayland werkt (geen wl-copy).

#### Scenario: Gegenereerde config
- **WHEN** de bmc-config wordt gegenereerd
- **THEN** bevat hij `rbw code` en geen `wl-copy`
