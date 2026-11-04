# Design

## Context

Uitgewerkt in een `/opsx:explore`-sessie op 2026-11-04 (epic nixos-54um). De agent draait op
malandro en mag alleen bouwen/evalueren, geen `switch` en geen sleutels maken.

## Decisions

### Kaal host-blok
mpenzi krijgt een eigen `nixosSystem` naar model van karlapi. Alles van lobos (Hyprland,
extraPkgs, overlays, home-manager) zou een Windows-overstapper alleen in de weg zitten en de
closure groot maken.

### Plasma-defaults via /etc/xdg, niet plasma-manager
KConfig leest `/etc/xdg` als systeemlaag onder `~/.config`. Defaults zetten zonder de keuzes van
Maaike bij elke deploy terug te draaien kan alleen zo.

### Nebula schakelt zichzelf in zodra de certificaten er zijn
`modules/nebula.nix` controleert met `builtins.pathExists` of `secrets/nebula-ca.crt.age` en
`nebula-<host>.{crt,key}.age` bestaan. Zo niet, dan blijft Nebula uit en geeft de evaluatie een
warning. Zo bouwen alle drie de hosts nu al, en wordt de mesh actief met alleen het toevoegen van
de `.age`-bestanden. Een `pki`-optie met platte paden bestaat alleen voor de VM-test.

### Toegangsbeleid centraal, Nebula-firewall als enige poortwachter
De hosts-tabel in de module bevat IP en inbound-regels per host. De host-firewall vertrouwt
`nebula.toorren`; anders bestaan er twee regelsets die uit elkaar kunnen lopen. Op de underlay
(wifi/LAN) gaan geen extra poorten open.

### Lighthouse-adressen
Eerst het LAN-adres van malandro (192.168.2.52), dan `wg.toorren.net` (wijst al naar het
thuis-IP). Thuis is dan geen NAT-hairpin nodig. malandro is ook relay, voor als twee laptops
achter NAT elkaar niet direct vinden.

### Subnet
10.77.0.0/24 botst niet met wg-easy (10.8.0.0/24), docker (172.17-22.0.0/16) of het LAN
(192.168.2.0/24).

### RustDesk als systeemservice
nixpkgs levert voor de client geen service. Zonder `rustdesk --service` neemt RustDesk alleen
verbindingen aan als het venster open is. De unit volgt het upstream .deb-pakket. `direct-server
= 'Y'` wordt in de root-config gezet als die optie nog ontbreekt. Op echte hardware is dat niet
getest; docs/mpenzi.md beschrijft de controle in de GUI.

### Jitsi als webapp
`jitsi-meet-electron` hangt in nixpkgs 26.05 aan Electron 41, dat EOL is en als insecure staat
gemarkeerd. Voor een beginnende gebruiker zetten we geen insecure pakket aan; Jitsi in Chrome is
gelijkwaardig.

### Beheer
`nix.settings.trusted-users = [ "root" "@wheel" ]` is nodig voor `--target-host wtoorren@mpenzi`,
want de closure gaat ongesigneerd over. Sudo vraagt een wachtwoord (`--ask-sudo-password`).

## Risks / Trade-offs

- RustDesk direct-server-seed niet op hardware geverifieerd → handmatige controle in de docs.
- Met de publieke ID-server van RustDesk aan blijft een verbinding op ID mogelijk (met
  wachtwoord). Uitzetten is een vervolgstap, niet in deze change.
- `wg.toorren.net` als lighthouse-naam koppelt Nebula aan dat DNS-record.
