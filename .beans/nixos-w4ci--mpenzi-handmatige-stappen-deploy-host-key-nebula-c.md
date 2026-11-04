---
# nixos-w4ci
title: 'mpenzi: handmatige stappen (deploy, host-key, Nebula-CA, router, sysadmin weg)'
status: todo
type: task
priority: normal
tags:
    - handmatig
created_at: 2026-11-04T16:26:56Z
updated_at: 2026-11-04T17:29:46Z
parent: nixos-54um
blocked_by:
    - nixos-nkux
    - nixos-e41o
---

NIET door de agent: deze stappen vragen de fysieke laptop, de router of geheime sleutels.

1. Eerste deploy lokaal op mpenzi als `sysadmin` (repo klonen of `--target-host sysadmin@<ip>`).
2. Host-key `/etc/ssh/ssh_host_ed25519_key.pub` van mpenzi in `secrets/secrets.nix` zetten.
3. Nebula-CA maken met `nebula-cert ca -name toorren -duration 43800h` (5 jaar; zonder `-duration` verloopt de CA na 1 jaar en valt de toegang stil weg); CA-key in Vaultwarden, NIET in de repo.
4. Certs per host (`nebula-cert sign -name <host> -ip 10.77.0.X/24`) en als .age versleutelen met `ragenx` (niet `agenix`), vanuit `secrets/`: `EDITOR="cp <tmp>/<host>.crt" ragenx -e nebula-<host>.crt.age` (idem `.key`, en `ca.crt` → `nebula-ca.crt.age`). Controleer met `ragenx -d`.
5. Router: UDP 4242 doorsturen naar malandro.
6. Controleren: `ssh wtoorren@mpenzi.local` + `sudo`, dan `sysadmin` uit de config halen en opnieuw deployen.


## Aanvullingen uit de implementatie (2026-11-04)

7. Wachtwoorden zetten op mpenzi: `sudo passwd maaike` en `sudo passwd wtoorren` (die is nodig voor sudo bij `--ask-sudo-password`). Wachtwoorden staan bewust niet in de publieke repo.
8. Na de host-key van mpenzi: in `secrets/secrets.nix` de variabele `mpenzi` toevoegen, de twee uitgecommentarieerde `nebula-mpenzi`-regels aanzetten, mpenzi bij `nebula-ca.crt.age` zetten en rekeyen met `ragenx -r` (niet `agenix -r`).
9. De `.age`-bestanden van Nebula `git add`-en; de flake ziet alleen getrackte bestanden en zet Nebula pas dan aan.
10. RustDesk op mpenzi: controleer dat Instellingen → Beveiliging → "Directe IP-toegang" aan staat (poort 21118). De seed in de service is niet op hardware getest.
11. Test vanaf lobos: `ping 10.77.0.3`, `ssh wtoorren@10.77.0.3`, RustDesk naar `10.77.0.3`.
12. Gebruik NIET `home/RUNME.sh new_nebula_node`: dat script gaat uit van een CA-sleutel in de repo.

Details: docs/mpenzi.md
