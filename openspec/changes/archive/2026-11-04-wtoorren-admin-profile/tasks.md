# Tasks

## 1. Profiel (bean nixos-xa9h)

- [x] 1.1 `home/shell-tools.nix` uit `home/common.nix`. Controle: drvPath `wtoorren@linuxserver` (`--impure`) gelijk aan de nulmeting.
- [x] 1.2 `home/profiles/wtoorren-admin/{default,base}.nix`: optie `toorren.admin.aws.enable`, zsh, tmux, rbw-configs, shell-tools, pinentry-tty.

## 2. zsh runtime-checks (bean nixos-6cig)

- [x] 2.1 `SSH_AUTH_SOCK` alleen zonder `SSH_CONNECTION`; AWS-wrappers alleen met `~/.aws/credentials`; prompt/tmux zonder `active-profile`.

## 3. AWS-deel (bean nixos-vza6)

- [x] 3.1 `aws.nix`: bmc/race altijd, `awsconf.nix` achter `aws.enable`, bmc `config.json` met tmux/OSC 52.

## 4. NixOS-module (bean nixos-toj0)

- [x] 4.1 `modules/wtoorren-admin.nix` met enable/aws.enable/createUser.
- [x] 4.2 mpenzi: module aan, eigen `users.users.wtoorren` weg, flake-comment bijwerken. Controle: eval van groepen/sleutel/shell.

## 5. Standalone (bean nixos-qq9o)

- [x] 5.1 `homeConfigurations."wtoorren@admin"` (genericLinux, stateVersion 25.11). Controle: activationPackage bouwt zonder `--impure`.

## 6. Tests en docs (bean nixos-682w)

- [x] 6.1 VM-test `checks.x86_64-linux.wtoorren-admin`: zsh-login, bmc zonder/met credentials, SSH_AUTH_SOCK met SSH_CONNECTION.
- [x] 6.2 Builds: mpenzi toplevel, `wtoorren@admin`, `wtoorren@linuxserver`; eval met aws.enable (`--impure`) levert `.aws/config`; mpenzi-generatie zonder `.aws/config`; bmc-config zonder wl-copy.
- [x] 6.3 `docs/wtoorren-admin.md` + indexregel `CLAUDE.md`, CHANGELOG.
