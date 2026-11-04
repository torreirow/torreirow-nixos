## Context

De shell-omgeving van Wouter staat in `home/` en wordt gebruikt door `wtoorren@linuxdesktop`
(lobos) en `wtoorren@linuxserver` (malandro, en nu ook nixhost). Die modules zitten vol met
lobos-specifieke zaken (Wayland, agenix-paden, seahorse, repo-paden onder `~/data/git`). Epic
nixos-tesy legt de keuzes vast; dit document beschrijft de uitwerking.

## Goals / Non-Goals

**Goals:**
- Eén HM-profiel, twee ingangen: NixOS-module (mpenzi) en standalone (nixhost).
- Een nieuwe NixOS-host is met `toorren.admin.enable = true` beheerbaar.
- Lobos en malandro veranderen niet.

**Non-Goals:**
- malandro omzetten (daar draait standalone HM; twee HM-bronnen voor één user botsen).
- AWS-credentials of `managed_service_accounts.json` beheren.
- rbw/pinentry in een kale SSM-sessie laten werken (inloggen gaat via ssh).
- Passwordless sudo.

## Decisions

**Module als functie van flake-inputs.** `modules/wtoorren-admin.nix` is
`{ home-manager, nixvim, bmc, race }: { config, lib, pkgs, unstable, ... }: …`. De flake roept
hem aan met de inputs. Alternatief `specialArgs` zou het mpenzi-blok en de VM-test extra
plumbing geven; zo blijft de import één regel.

**Optieset in het HM-profiel.** `toorren.admin.aws.enable` is een home-manager-optie in
`home/profiles/wtoorren-admin/default.nix`. De NixOS-module zet hem door; standalone zet je hem
direct. Daardoor heeft het profiel geen NixOS-`config` nodig.

**Pakketten via `extraSpecialArgs.adminInputs`.** bmc en race komen als
`adminInputs.<naam>.packages.${pkgs.stdenv.hostPlatform.system}`; zo werkt elke architectuur
waarvoor de inputs pakketten leveren.

**`~/.aws/config` hergebruikt `home/awsconf.nix` achter `mkIf`.** aws.nix importeert de optie-
module `awscli_custom.nix` en zet de `programs`/`systemd`-attributen van `awsconf.nix` alleen bij
`aws.enable`. Uitgeschakeld wordt `awsconf.nix` niet geëvalueerd, dus geen `--impure` nodig.

**Runtime-checks in zsh, niet build-time.** Nix evalueert op lobos; `pathExists ~/.aws` zegt
niets over de doelhost. De AWS-wrappers staan in een `if [[ -f ~/.aws/credentials ]]`-blok; het
blok kijkt niet naar `~/.aws` omdat HM die map zelf aanmaakt.

**Eigen zsh-config in het profiel.** `home/zsh.nix` zet `SSH_AUTH_SOCK` onvoorwaardelijk en bevat
Wayland- en lobos-functies. Het profiel krijgt een eigen, kleine `programs.zsh` en deelt de
bronbestanden (oh-my-zsh-thema, completions, rbw-configs) via paden naar `home/dotfiles`. tmux
gebruikt `home/tmux.nix` ongewijzigd.

**Gedeelde shell-tools.** atuin/fzf/direnv/jq verhuizen ongewijzigd naar `home/shell-tools.nix`;
`home/common.nix` importeert die. Controle: de drvPath van `wtoorren@linuxserver` blijft gelijk.
`wtoorren@linuxdesktop` is op malandro niet te evalueren (pad-input hyprquickframe heeft daar een
andere hash); hij deelt dezelfde `common.nix`, dus dezelfde redenering geldt.

**bmc-config.** `copy_command = "tmux load-buffer -w -"`: bmc voert het zonder shell uit en geeft
de code via stdin; tmux stuurt de buffer met OSC 52 naar het clipboard van de terminal op lobos
(`set-clipboard on` staat al in `home/tmux.nix`). Geen `paste_command` (headless). Buiten tmux
faalt alleen het kopiëren; bmc meldt dat en gaat door.

**createUser.** Maakt `users.users.wtoorren` met wheel (+ networkmanager als NetworkManager aan
staat), de ssh-sleutel `wtoorren` en zsh. Zet `trusted-users = [ "@wheel" ]` en, met `mkDefault`,
openssh met alleen sleutels. Geen uid: NixOS bewaart de uid in zijn uid-map, dus mpenzi houdt
1002.

## Risks / Trade-offs

- [bmc-config niet 1-op-1 met lobos] lobos was niet bereikbaar om de echte `config.json` te
  lezen → `totpScript`/`profileScripts` zijn opties met de waarden uit de epic; docs vragen om
  vergelijken.
- [Twee zsh-configs] profiel en `home/zsh.nix` lopen uit elkaar → bewust: het profiel is klein en
  servergericht; gedeelde bronbestanden blijven gedeeld.
- [atuin-daemon/auto_sync] synct naar de TechNative-server zodra Wouter inlogt; zonder login doet
  hij niets.
