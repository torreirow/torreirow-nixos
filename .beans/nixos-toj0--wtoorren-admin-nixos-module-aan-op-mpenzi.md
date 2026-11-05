---
# nixos-toj0
title: 'wtoorren-admin: NixOS-module + aan op mpenzi'
status: completed
type: task
priority: normal
created_at: 2026-11-04T20:39:33Z
updated_at: 2026-11-04T22:03:45Z
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


- Optie `toorren.admin.createUser` (default `true`): maakt `users.users.wtoorren` aan met
  `isNormalUser`, `description = "Wouter"`, `extraGroups = [ "wheel" ]` (+ `networkmanager` als
  NetworkManager aan staat), `openssh.authorizedKeys.keys` = sleutel `wtoorren` uit `secrets/secrets.nix`,
  `shell = pkgs.zsh`. Zet ook `nix.settings.trusted-users = [ "@wheel" ]` (nodig voor `--target-host`)
  en `services.openssh.enable` met alleen key-auth als de host dat nog niet doet (mkDefault).
- mpenzi: de eigen `users.users.wtoorren`-definitie in `hosts/mpenzi/configuration.nix` vervalt; de
  module is de enige bron. Eval moet daarna hetzelfde account opleveren (uid blijft 1002, `wheel`,
  `networkmanager`, dezelfde sleutel).
- `createUser = false` voor hosts die het account zelf beheren; dan zet de module alleen HM aan.


## Summary of Changes

`modules/wtoorren-admin.nix` (functie van de inputs home-manager/nixvim/bmc/race), opties enable/aws.enable/createUser. mpenzi: eigen users.users.wtoorren weg, `toorren.admin.enable = true`; eval: wheel+networkmanager+sleutel+zsh, alleen de module definieert het account. Geen wheelNeedsPassword/sshAgentAuth.
