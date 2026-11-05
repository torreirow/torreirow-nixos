---
# nixos-8tac
title: 'maaike: HM-profiel als NixOS-module + Firefox/Chrome/Thunderbird-policies'
status: completed
type: task
priority: normal
created_at: 2026-11-04T21:10:32Z
updated_at: 2026-11-05T08:36:17Z
parent: nixos-kzxu
---

HM voor maaike als NixOS-module + policies.
- `home-manager.users.maaike = import ../../home/profiles/maaike` (deel de HM-NixOS-integratie met wtoorren-admin als die er al is; anders zelf importeren, `useGlobalPkgs`).
- Firefox-, Chrome- en Thunderbird-policies op systeemniveau (zie epic).


## Summary of Changes

- `modules/maaike-apps.nix` (`toorren.maaike.enable`): home-manager voor maaike met `home/profiles/maaike` (alleen seeds, geen plasma-manager); mpenzi zet het aan. De HM-module komt via wtoorren-admin.
- wtoorren-admin: nixvim van `sharedModules` naar `users.wtoorren.imports` (anders ook bij maaike). Bewezen met een marker-stub: wtoorrens HM-drv gelijk, marker alleen bij wtoorren.
- `hosts/mpenzi/apps.nix`: Firefox `force_installed` Bitwarden + uBlock Origin, Chrome `programs.chromium.extensions` Bitwarden + uBlock Origin Lite, Thunderbird-policy (offline-sync, telemetrie uit).
