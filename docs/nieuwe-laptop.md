# Nieuwe eindgebruikers-laptop toevoegen (zoals mpenzi)

Draaiboek op basis van de uitrol van mpenzi (2026-11-04). Reken op 1 tot 1,5 uur, vooral
wachttijd op builds. Achtergrond van mpenzi zelf: `docs/mpenzi.md`.

Voorbeeldwaarden hieronder: laptop `<naam>`, gebruiker `<gebruiker>`, Nebula-IP `10.77.0.4`.
Kies het volgende vrije adres uit de `hosts`-tabel in `modules/nebula.nix`.

## A. Op de nieuwe laptop (~15 min)

1. NixOS 26.05 installeren met de grafische installer: Plasma, schijfversleuteling (LUKS) aan,
   tijdelijke gebruiker `sysadmin`.
2. In `/etc/nixos/configuration.nix` toevoegen en `sudo nixos-rebuild switch` draaien:
   ```nix
   services.openssh.enable = true;
   nix.settings.trusted-users = [ "root" "@wheel" ];
   ```
   Zonder ssh kan lobos niet deployen; zonder `trusted-users` weigert de nix-daemon de
   ongesigneerde closure van lobos.
3. `hardware-configuration.nix` naar lobos kopiëren, **plus** de LUKS-regel voor swap uit
   `configuration.nix`. Die staat niet in het hardware-bestand; zonder die regel boot swap niet.

## B. Op lobos, in de repo (~20 min)

1. `hosts/mpenzi/` kopiëren naar `hosts/<naam>/` en aanpassen: hardware-config + swap-regel,
   hostnaam, gebruiker (i.p.v. `maaike`), `system.stateVersion`. Het mpenzi-blok in `flake.nix`
   kopiëren voor `<naam>`.
2. Zodra het profiel `wtoorren-admin` er is (epic `nixos-tesy`): `toorren.admin.enable = true;`.
   Dat maakt account `wtoorren` aan (wheel + ssh-sleutel) en zet home-manager aan.
3. In `modules/nebula.nix` de laptop aan `hosts` toevoegen, met dezelfde inbound-regels als
   mpenzi (tcp 22 en 21118, alleen van `lobos`).
4. Eerste deploy. Nebula blijft nog uit (er is nog geen certificaat; de build geeft alleen een
   warning):
   ```bash
   command nixos-rebuild switch --flake .#<naam> \
     --target-host sysadmin@<lan-ip> --sudo --ask-sudo-password
   ```
5. Op de laptop wachtwoorden zetten: `sudo passwd <gebruiker>` en `sudo passwd wtoorren`.
   Wachtwoorden staan bewust niet in de (publieke) repo.

## C. Nebula-certificaat (~15 min)

1. Host-key ophalen: `ssh wtoorren@<naam>.local cat /etc/ssh/ssh_host_ed25519_key.pub`.
   In `secrets/secrets.nix`: variabele `<naam>` toevoegen, regels voor
   `nebula-<naam>.crt.age` en `nebula-<naam>.key.age` (`users ++ [ <naam> ]`), `<naam>` bij
   `nebula-ca.crt.age` zetten. Daarna vanuit `secrets/`: `ragenx -r`.
2. Certificaat tekenen in een tmpfs-map, met de CA-sleutel uit Vaultwarden en de nebula-versie
   van de hosts:
   ```bash
   T=$(mktemp -d -p /run/user/$UID nebula.XXXX); umask 077
   rbw get --full "nebula-ca toorren" | sed -n '/BEGIN/,/END/p' > $T/ca.key
   (cd secrets && ragenx -d nebula-ca.crt.age) > $T/ca.crt
   NB=$(nix build --no-link --print-out-paths .#nixosConfigurations.lobos.pkgs.nebula)
   (cd $T && $NB/bin/nebula-cert sign -ca-key ca.key -ca-crt ca.crt \
     -name <naam> -networks 10.77.0.4/24)
   ```
3. Versleutelen via **stdin** (vanuit `secrets/`), controleren en opruimen:
   ```bash
   cd secrets
   ragenx -e nebula-<naam>.crt.age < $T/<naam>.crt
   ragenx -e nebula-<naam>.key.age < $T/<naam>.key
   ragenx -d nebula-<naam>.crt.age | cmp - $T/<naam>.crt && echo OK
   shred -u $T/* && rmdir $T
   ```
4. `git add secrets/nebula-<naam>.*.age` (de flake ziet alleen getrackte bestanden; pas dan gaat
   Nebula aan), committen, opnieuw deployen, testen met `ping 10.77.0.4`.

## D. Afronden

1. `sysadmin` uit de config halen en deployen, nu via Nebula:
   ```bash
   command nixos-rebuild switch --flake .#<naam> \
     --target-host wtoorren@10.77.0.4 --sudo --ask-sudo-password
   ```
   Controleer eerst dat `ssh wtoorren@10.77.0.4` en `sudo` werken.
2. RustDesk testen: de gebruiker opent de app en keurt "scherm delen" goed; vanaf lobos
   verbinden met `10.77.0.4`.

## Valkuilen (uit de uitrol van mpenzi)

| Valkuil                                     | Oplossing                                          |
|---------------------------------------------|----------------------------------------------------|
| Alias `nixos-rebuild` = `sudo nixos-rebuild` | `command nixos-rebuild ...`; als root ontbreekt de rbw-ssh-agent (`Permission denied (publickey)`) |
| `nice ... command nixos-rebuild` faalt      | `command` is een shell-builtin; gebruik het volle pad `/run/current-system/sw/bin/nixos-rebuild` |
| `--ask-sudo-password` via `!` in Claude Code | hangt; in een eigen terminal draaien              |
| `ragenx` vindt `secrets.nix` niet           | vanuit `secrets/` draaien                          |
| `EDITOR="cp ..." ragenx -e` maakt leeg bestand | stdin is geen terminal, dan leest ragenx stdin: `ragenx -e x.age < bestand` |
| rbw op slot                                 | ook git-over-ssh en `rbw get` falen; eerst `rbw unlock` |
| `rbw add` faalt (422) bij de CA-sleutel     | `bw` gebruiken: secure note via `bw get template item \| jq ... \| bw encode \| bw create item` |
| RustDesk-poort 21118 dicht                  | onder Wayland doet `rustdesk --service` niets; de gebruiker opent de app zelf |
| Nebula-CA zonder `-duration`                | verloopt na 1 jaar; de huidige CA loopt tot 2031-11-03 |
