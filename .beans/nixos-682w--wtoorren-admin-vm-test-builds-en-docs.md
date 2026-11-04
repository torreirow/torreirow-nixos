---
# nixos-682w
title: 'wtoorren-admin: VM-test, builds en docs'
status: todo
type: task
priority: normal
created_at: 2026-11-04T20:39:33Z
updated_at: 2026-11-04T20:52:07Z
parent: nixos-tesy
blocked_by:
    - nixos-toj0
    - nixos-6cig
    - nixos-vza6
    - nixos-qq9o
---

Testen en documenteren.

- `nixosTest` in `modules/wtoorren-admin_vmtest.nix` (zoals `modules/nebula_vmtest.nix`): de vier
  runtime-scenario's uit de acceptatiecriteria van de epic.
- Builds: mpenzi toplevel, `wtoorren@linuxdesktop` (`--impure`), `wtoorren@linuxserver`.
- `docs/wtoorren-admin.md`: aanzetten op een host, `aws.enable` + `--impure`, credentials handmatig,
  bmc config.json handmatig, waarom malandro (nog) niet. Indexregel in `CLAUDE.md`.


- Ook bouwen: `homeConfigurations."wtoorren@admin".activationPackage`. VM-test of eval-check dat de bmc-config geen `wl-copy` bevat.
- Docs: SSM-sessie werkt niet met rbw/pinentry op nixhost; inloggen via ssh (ook ssh-over-SSM).
