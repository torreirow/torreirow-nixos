---
# nixos-nkux
title: 'mpenzi: host-basis (flake-blok, hardware, LUKS, gebruikers, ssh)'
status: completed
type: task
priority: normal
created_at: 2026-11-04T16:26:56Z
updated_at: 2026-11-04T18:03:38Z
parent: nixos-54um
---

Nieuw host-blok `nixosConfigurations.mpenzi` in `flake.nix` (kaal, model `karlapi`: alleen `unstable`-arg +
`agenix.nixosModules.default`; geen tnaws/extraPkgs/lobos-overlays). Bestanden onder `hosts/mpenzi/`:
`configuration.nix` + `hardware-configuration.nix` (inhoud: zie epic, inclusief de swap-LUKS-regel).

- systemd-boot, NetworkManager, pipewire, hostnaam `mpenzi`
- `nl_NL.UTF-8`, xkb `us` + variant `intl`, console via `useXkbConfig`
- gebruikers `maaike` (geen wheel), `wtoorren` (wheel + key), `sysadmin` voorlopig behouden
- `services.openssh` aan, `PasswordAuthentication = false`, `PermitRootLogin = "no"`
- avahi met `nssmdns4` zodat `mpenzi.local` thuis werkt
- `nixpkgs.config.allowUnfree = true`, `fwupd` aan, `nix.gc` wekelijks


## Resultaat

Host-blok in flake.nix, hosts/mpenzi/{configuration,hardware-configuration}.nix. Toplevel-build en acceptatie-eval geslaagd (maaike geen wheel, wtoorren wheel+key, ssh key-only, geen autoUpgrade). OpenSpec: mpenzi-laptop.
