# wtoorren-admin: Wouters shell op andere hosts

Herbruikbaar home-manager-profiel voor hosts buiten lobos en malandro: zsh (oh-my-zsh, thema
wouter), tmux, nixvim, rbw (profielen toorren en technative), atuin/fzf/direnv/jq, bmc en race.
OpenSpec-change `wtoorren-admin-profile`, epic `nixos-tesy`.

| Onderdeel         | Bestand                                                          |
|-------------------|------------------------------------------------------------------|
| Profiel           | `home/profiles/wtoorren-admin/{default,base,aws}.nix`            |
| NixOS-module      | `modules/wtoorren-admin.nix`                                     |
| Standalone        | `homeConfigurations."wtoorren@admin"` in `flake.nix`             |
| Gedeeld met lobos | `home/shell-tools.nix`, `home/zsh-rbwsel.nix`, `home/tmux.nix`   |
| VM-test           | `modules/wtoorren-admin_vmtest.nix`                              |

## Aanzetten

**NixOS-host** (zoals mpenzi). Importeer de module in het host-blok van `flake.nix`:

```nix
(import ./modules/wtoorren-admin.nix { inherit home-manager nixvim bmc race; })
```

en zet in de host-config `toorren.admin.enable = true;`. Het host-blok moet `unstable` als
module-argument hebben (zoals `defaults` in het mpenzi-blok).

| Optie                       | Default | Wat                                                    |
|-----------------------------|---------|--------------------------------------------------------|
| `toorren.admin.enable`      | uit     | profiel voor `wtoorren` via home-manager, zsh als shell |
| `toorren.admin.aws.enable`  | uit     | `~/.aws/config` genereren (vraagt `--impure`)          |
| `toorren.admin.createUser`  | aan     | account `wtoorren`: wheel, ssh-sleutel, trusted-user   |

Met `createUser` zet de module ook openssh aan met alleen sleutels (`mkDefault`). sudo vraagt
een wachtwoord; deployen blijft `--sudo --ask-sudo-password`. Een host die `wtoorren` zelf
definieert, zet `createUser = false`.

**Niet-NixOS-host** (nixhost). Op de host zelf, ingelogd via ssh:

```bash
home-manager switch --flake .#wtoorren@admin -b backup
```

nixhost draaide tot nu toe `wtoorren@linuxserver`. Dat is voor malandro bedoeld: met lobos-paden,
wl-copy en een vaste SSH-agent. `-b backup` zet bestanden die al bestaan opzij. In de standalone
ingang zet je `toorren.admin.aws.enable` in het moduleblok in `flake.nix`.

## Gedrag op runtime

- `SSH_AUTH_SOCK` wijst naar de rbw-agent zolang `$SSH_CONNECTION` leeg is. Via ssh blijft de
  doorgestuurde agent (`ssh -A`) staan.
- De functie `bmc` en de aliassen `bmcp`, `aws-switch`, `tfplan`, `tfapply`, `tfbackend` bestaan
  alleen als `~/.aws/credentials` er is. De pakketten bmc en race staan er altijd. De check kijkt
  naar het bestand en niet naar `~/.aws`, want die map maakt home-manager zelf aan.
- Een build-time-check kan niet: Nix evalueert op lobos en ziet de doelhost niet.

## AWS

- **Credentials** zet Wouter met de hand in `~/.aws/credentials`, alleen op hosts waar hij AWS
  wil. Nooit via Nix of agenix.
- **`~/.aws/config`** komt alleen met `aws.enable`. Het gebruikt `home/awsconf.nix`, net als
  lobos, en leest `~/.aws/managed_service_accounts.json` op de machine die bouwt. Daarom is
  `--impure` nodig. Zonder dat bestand krijg je een waarschuwing en alleen de vaste profielen.
- **`~/.config/bmc/config.json`** beheert het profiel:
  - MFA staat aan.
  - `totp_script` is `rbw code "Technative AWS (new)"`.
  - `copy_command` is `tmux load-buffer -w -`: tmux stuurt de code met OSC 52 naar het
    clipboard van lobos.
  - Er is geen `paste_command`.
  - Buiten tmux meldt bmc alleen dat het kopiëren mislukte.
  - Per-profiel-scripts en `console`-instellingen van lobos zijn niet overgenomen; lobos was bij
    het maken niet bereikbaar. Vergelijk met `~/.config/bmc/config.json` op lobos en zet
    verschillen in `toorren.admin.bmc.{totpScript,profileScripts}`.

## SSM

Op nixhost werken rbw en pinentry niet in een kale SSM-sessie: er is geen tty voor pinentry en
geen user-sessie voor de agent. Log in met ssh, ook als dat over SSM gaat (`ssh` met een
SSM-ProxyCommand).

## Waarom (nog) niet op malandro

Op malandro draait `wtoorren@linuxserver` als standalone home-manager. De NixOS-module ernaast
zou een tweede home-manager-bron voor dezelfde gebruiker zijn, en die twee botsen. Eerst moet
de standalone versie daar weg. lobos houdt `wtoorren@linuxdesktop`.

## Testen

```bash
nix build .#checks.x86_64-linux.wtoorren-admin -L        # VM: zsh, bmc, SSH_AUTH_SOCK, bestanden
nix build '.#homeConfigurations."wtoorren@admin".activationPackage'
nix build .#nixosConfigurations.mpenzi.config.system.build.toplevel
```
