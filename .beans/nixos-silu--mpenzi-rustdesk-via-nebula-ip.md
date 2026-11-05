---
# nixos-silu
title: 'mpenzi: RustDesk via Nebula-IP'
status: completed
type: task
priority: normal
created_at: 2026-11-04T16:26:56Z
updated_at: 2026-11-04T18:03:39Z
parent: nixos-54um
blocked_by:
    - nixos-e41o
---

RustDesk op mpenzi zonder publieke relay: verbinden via het Nebula-IP.

- `rustdesk-flutter` installeren, autostart voor `maaike`.
- Direct IP access aanzetten als systeem-default (RustDesk-optie `direct-server = 'Y'`, poort 21118);
  uitzoeken of dat via een systeemconfig kan of een eenmalige stap in `docs/mpenzi.md` moet worden.
- RustDesk op lobos beschikbaar maken (alleen het pakket).


## Resultaat

hosts/mpenzi/rustdesk.nix: `rustdesk --service` als systeemservice met direct-server-seed; rustdesk-flutter op lobos. GUI-controle op hardware staat in nixos-w4ci (stap 10). OpenSpec: mpenzi-laptop.
