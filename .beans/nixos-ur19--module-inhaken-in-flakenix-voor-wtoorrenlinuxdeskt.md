---
# nixos-ur19
title: Module inhaken in flake.nix voor wtoorren@linuxdesktop
status: completed
type: task
priority: normal
created_at: 2026-08-31T10:50:05Z
updated_at: 2026-08-31T10:59:54Z
parent: nixos-3es6
---

Module-import ./home/module/nextcloud-sync toegevoegd aan modules-lijst van homeConfigurations."wtoorren@linuxdesktop" in flake.nix. Geverifieerd: nix eval (default enable=false schoon), extendModules (enabled units correct), nix build activationPackage end-to-end succesvol.
