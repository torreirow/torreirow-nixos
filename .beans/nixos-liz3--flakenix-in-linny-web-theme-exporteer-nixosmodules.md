---
# nixos-liz3
title: 'flake.nix in linny-web-theme: exporteer nixosModules.linny-web (+ default), plain nix, eval-check'
status: completed
type: task
priority: normal
created_at: 2026-09-04T08:32:35Z
updated_at: 2026-09-04T11:37:58Z
parent: nixos-dhh8
---

flake.nix in de linny-web-theme repo. inputs: nixpkgs (nixos-26.05). outputs: nixosModules.linny-web = import ./nix/linny-web.nix; nixosModules.default. Plain nix voor systems (x86_64-linux, aarch64-linux), GEEN flake-utils. checks.<system>.eval evalueert een voorbeeldconfig met de module.
