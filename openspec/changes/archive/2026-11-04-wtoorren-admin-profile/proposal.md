## Why

Wouter beheert hosts buiten lobos en malandro (nu mpenzi, straks meer) zonder zijn eigen
shell-omgeving. Op nixhost (niet-NixOS) draait `wtoorren@linuxserver`, dat voor malandro bedoeld
is en daar maar half werkt (lobos-paden, wl-copy, een vaste SSH-agent). Een nieuwe NixOS-host
beheerbaar maken vraagt nu telkens een eigen gebruikersblok.

## What Changes

- Nieuw herbruikbaar home-manager-profiel `home/profiles/wtoorren-admin/`: zsh (oh-my-zsh, thema
  wouter), tmux, nixvim, rbw (twee profielen), atuin/fzf/direnv/jq, plus bmc en race.
- Runtime-gedrag in zsh: `SSH_AUTH_SOCK` alleen naar de rbw-agent zonder ssh-sessie; de
  AWS-wrappers (bmc, bmcp, aws-switch, tfplan/tfapply/tfbackend) alleen als `~/.aws/credentials`
  bestaat.
- `~/.config/bmc/config.json` beheerd: MFA via `rbw code`, kopiëren via tmux/OSC 52 in plaats van
  wl-copy.
- `~/.aws/config` alleen bij `toorren.admin.aws.enable` (vraagt `--impure`).
- NixOS-module `modules/wtoorren-admin.nix` met `toorren.admin.{enable,aws.enable,createUser}`;
  `createUser` maakt het beheeraccount `wtoorren` (wheel, ssh-sleutel, zsh).
- Standalone `homeConfigurations."wtoorren@admin"` voor niet-NixOS-hosts (nixhost).
- mpenzi zet het profiel aan; het eigen `users.users.wtoorren`-blok vervalt.
- `home/shell-tools.nix`: atuin/fzf/direnv/jq uit `home/common.nix` gehaald zodat lobos/malandro
  en het profiel dezelfde code delen (uitvoer voor lobos/malandro ongewijzigd).
- VM-test `checks.x86_64-linux.wtoorren-admin` en een eval-check voor `aws.enable`.

## Capabilities

### New Capabilities
- `wtoorren-admin-profile`: het beheerprofiel voor Wouter op hosts buiten lobos en malandro.

### Modified Capabilities

## Impact

- Nieuw: `modules/wtoorren-admin.nix`, `modules/wtoorren-admin_vmtest.nix`,
  `home/profiles/wtoorren-admin/{default,base,aws}.nix`, `home/shell-tools.nix`,
  `docs/wtoorren-admin.md`.
- Gewijzigd: `flake.nix` (mpenzi-blok, `wtoorren@admin`, check), `home/common.nix` (import i.p.v.
  inline), `hosts/mpenzi/configuration.nix`, `CLAUDE.md`, `CHANGELOG.md`.
- Niet gewijzigd: `wtoorren@linuxdesktop`/`wtoorren@linuxserver` inhoudelijk, malandro, lobos.
