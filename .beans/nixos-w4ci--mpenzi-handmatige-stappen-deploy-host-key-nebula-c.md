---
# nixos-w4ci
title: 'mpenzi: handmatige stappen (deploy, host-key, Nebula-CA, router, sysadmin weg)'
status: todo
type: task
tags:
    - handmatig
created_at: 2026-11-04T16:26:56Z
updated_at: 2026-11-04T16:26:56Z
parent: nixos-54um
blocked_by:
    - nixos-nkux
    - nixos-e41o
---

NIET door de agent: deze stappen vragen de fysieke laptop, de router of geheime sleutels.

1. Eerste deploy lokaal op mpenzi als `sysadmin` (repo klonen of `--target-host sysadmin@<ip>`).
2. Host-key `/etc/ssh/ssh_host_ed25519_key.pub` van mpenzi in `secrets/secrets.nix` zetten.
3. Nebula-CA maken met `nebula-cert ca -name toorren`; CA-key in Vaultwarden, NIET in de repo.
4. Certs per host (`nebula-cert sign -name <host> -ip 10.77.0.X/24`) en als .age versleutelen met `ragenx`/agenix.
5. Router: UDP 4242 doorsturen naar malandro.
6. Controleren: `ssh wtoorren@mpenzi.local` + `sudo`, dan `sysadmin` uit de config halen en opnieuw deployen.
