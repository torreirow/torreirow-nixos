---
# nixos-qq9o
title: 'wtoorren-admin: standalone homeConfiguration wtoorren@admin (nixhost)'
status: todo
type: task
created_at: 2026-11-04T20:52:07Z
updated_at: 2026-11-04T20:52:07Z
parent: nixos-tesy
blocked_by:
    - nixos-xa9h
---

Standalone ingang voor niet-NixOS-hosts (eerste: nixhost).

- `homeConfigurations."wtoorren@admin"` in `flake.nix` op basis van `home/profiles/wtoorren-admin`,
  met `nixvim.homeModules.default`, `extraSpecialArgs.unstable`, `home.username`/`homeDirectory`.
- Opties ook hier beschikbaar (`toorren.admin.aws.enable`, default uit), zodat dezelfde profielcode
  geen NixOS-`config` nodig heeft. NixOS-module en standalone delen dus één HM-optieset.
- Niet-NixOS-specifiek: `pinentry-tty` in `home.packages` en als rbw-pinentry (er is geen
  `/run/current-system/sw/bin/pinentry-tty`); `nix.package`/`targets.genericLinux.enable` waar nodig.
- `wtoorren@linuxserver` niet aanpassen (malandro). In docs: hoe nixhost overstapt van
  `linuxserver` naar `admin` (`home-manager switch --flake .#wtoorren@admin -b backup`).
