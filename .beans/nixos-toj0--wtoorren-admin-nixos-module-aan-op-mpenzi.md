---
# nixos-toj0
title: 'wtoorren-admin: NixOS-module + aan op mpenzi'
status: todo
type: task
created_at: 2026-11-04T20:39:33Z
updated_at: 2026-11-04T20:39:33Z
parent: nixos-tesy
blocked_by:
    - nixos-xa9h
---

NixOS-module `modules/wtoorren-admin.nix`.

- Opties `toorren.admin.enable`, `toorren.admin.aws.enable`.
- Importeert `home-manager.nixosModules.home-manager` (flake-input bestaat al, release-26.05);
  `useGlobalPkgs = true`, `useUserPackages = true`, `extraSpecialArgs.unstable`,
  `sharedModules = [ nixvim.homeModules.default ]`.
- `home-manager.users.wtoorren = import ../home/profiles/wtoorren-admin`.
- `programs.zsh.enable = true` op systeemniveau en `users.users.wtoorren.shell = pkgs.zsh`.
- In `flake.nix` aan het mpenzi-blok toevoegen; de flake-comment "geen home-manager" bijwerken
  (geldt nu alleen voor Maaike).
