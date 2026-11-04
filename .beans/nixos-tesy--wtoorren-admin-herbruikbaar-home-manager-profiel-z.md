---
# nixos-tesy
title: 'wtoorren-admin: home-manager-profiel voor hosts buiten lobos/malandro (mpenzi, nixhost)'
status: in-progress
type: epic
priority: normal
created_at: 2026-11-04T20:39:33Z
updated_at: 2026-11-04T21:39:51Z
---

Herbruikbaar home-manager-profiel **wtoorren-admin**: de shell-omgeving van Wouter (zsh, tmux, nixvim,
rbw, en optioneel AWS-tooling bmc/race) op hosts buiten lobos en malandro (die blijven zoals ze zijn). Twee doelen:
**mpenzi** (NixOS, als NixOS-module) en **nixhost** (niet-NixOS, standalone home-manager; draait nu
`wtoorren@linuxserver` en daar werkt niet alles). Uitgewerkt in een explore-sessie op 2026-11-04. Maak bij uitvoering een OpenSpec change
(voorstel: `wtoorren-admin-profile`) en werk de child-beans af.

## Besloten

| Onderwerp      | Keuze                                                                                   |
|----------------|-----------------------------------------------------------------------------------------|
| Vorm           | Eén HM-profiel, twee ingangen: (1) **NixOS-module** voor NixOS-hosts (mpenzi): bouwt op lobos, gaat mee met `--target-host`; (2) **standalone** `homeConfigurations."wtoorren@admin"` voor niet-NixOS-hosts (nixhost): `home-manager switch --flake .#wtoorren@admin` op de host zelf. `wtoorren@linuxserver` blijft voor malandro |
| Bestanden      | `modules/wtoorren-admin.nix` (NixOS-module, opties) + `home/profiles/wtoorren-admin/` (HM-profiel: `default.nix`, `base.nix`, `aws.nix`) |
| Opties         | `toorren.admin.enable` (default false), `toorren.admin.aws.enable` (default false), `toorren.admin.createUser` (default true: maakt account wtoorren met wheel + ssh-sleutel, zodat een nieuwe NixOS-host met één regel beheerbaar is) |
| Basis          | zsh, tmux, nixvim, rbw (`programs.rbw` + `~/.config/rbw/config.json` en `rbw-technative`), atuin/fzf/direnv/jq |
| AWS-tools      | bmc en race-pakketten altijd installeren (zonder credentials doen ze niets)              |
| AWS-shell      | zsh-wrappers/aliassen (bmc-functie, bmcp, aws-switch, tfplan/tfapply/tfbackend) alleen als op **runtime** `~/.aws/credentials` bestaat. NIET op `~/.aws` checken: HM maakt die map zelf aan |
| `~/.aws/config`| Alleen bij `aws.enable = true` (build-time). Bevat klant-accountnummers en -namen uit `~/.aws/managed_service_accounts.json` en vraagt `--impure`; daarom default uit |
| bmc-config     | Het profiel beheert `~/.config/bmc/config.json` (nu niet door Nix beheerd, dus op nixhost ontbrekend of een kopie van lobos). Inhoud gelijk aan lobos: `mfa.enabled`, `totp_script = rbw code "Technative AWS (new)"`, `profile_scripts` (499164406685-wouter), `console`. Verschil: `copy_command`/`paste_command` zijn op lobos `wl-copy`/`wl-paste` en werken niet op een headless server; in het profiel iets dat over ssh werkt (voorkeur: OSC 52 / `tmux load-buffer -w -` zodat de code op het clipboard van lobos landt; tmux heeft al `set-clipboard on`) |
| SSM            | Buiten scope. Op nixhost werkt rbw/pinentry alleen via ssh, niet in een kale SSM-sessie (eerder onderzocht). Werkwijze: inloggen met ssh (ook ssh-over-SSM). Alleen documenteren |
| Credentials    | NOOIT via Nix/agenix. Wouter zet `~/.aws/credentials` met de hand op hosts waar hij AWS wil |
| SSH-agent      | `SSH_AUTH_SOCK` alleen naar de rbw-agent als er geen ssh-sessie is (`$SSH_CONNECTION` leeg), zodat `ssh -A` op servers werkt |
| mpenzi         | `toorren.admin.enable = true`, `aws.enable = false`. Maaike blijft zonder home-manager |

## Waarom build-time-detectie van ~/.aws niet kan

Nix evalueert op lobos; `builtins.pathExists ~/.aws` kijkt naar lobos, niet naar de doelhost. Alleen de
runtime-check in zsh ziet de echte toestand op de host.

## Grenzen voor de agent

- GEEN `nixos-rebuild switch`/`boot`, geen `home-manager switch`. Alleen build/eval/VM-test.
- `homeConfigurations."wtoorren@linuxdesktop"` en `"wtoorren@linuxserver"` mogen inhoudelijk niet
  veranderen voor lobos; als code gedeeld wordt, moeten ze blijven bouwen (linuxdesktop met `--impure`).
- malandro NIET omzetten: daar draait wtoorren mogelijk standalone HM (`linuxserver`); twee HM-bronnen
  voor dezelfde user botsen. Alleen documenteren hoe een host het profiel aanzet.
- Geen AWS-credentials of `managed_service_accounts.json` in de repo.
- Beans met tag `handmatig` niet uitvoeren.

## Acceptatiecriteria

- `nix build .#nixosConfigurations.mpenzi.config.system.build.toplevel` slaagt met het profiel aan.
- `nix build .#homeConfigurations."wtoorren@admin".activationPackage` slaagt (zonder `--impure` als `aws.enable` uit staat).
- De gegenereerde bmc-config bevat `totp_script` met `rbw code` en een copy-commando zonder `wl-copy`.
- In de HM-generatie van mpenzi staat geen `.aws/config`; wel zsh/tmux/nixvim/rbw-config.
- Eval met `aws.enable = true` (VM-test of eval-check, `--impure`) levert wel `.aws/config`.
- VM-test (`nixosTest`): login-shell zsh werkt; zonder `~/.aws/credentials` bestaat de bmc-functie niet,
  met een dummy-bestand wel; met `SSH_CONNECTION` gezet wijst `SSH_AUTH_SOCK` niet naar rbw.
- Eval van mpenzi met de module: `users.users.wtoorren` heeft `wheel`, `networkmanager` en de ssh-sleutel, en wordt alleen door de module gedefinieerd.
- `wtoorren@linuxdesktop` bouwt nog (`--impure`), `wtoorren@linuxserver` ook.
- Docs: `docs/wtoorren-admin.md` + indexregel in `CLAUDE.md`; OpenSpec change gearchiveerd.


## Besloten na aanmaken (2026-11-04)

- sudo blijft MET wachtwoord voor wtoorren: geen `wheelNeedsPassword = false` en geen `pam.sshAgentAuth` in de module. Deployen blijft `--sudo --ask-sudo-password`.
