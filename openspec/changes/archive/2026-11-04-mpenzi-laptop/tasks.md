# Tasks

## 1. Host-basis (bean nixos-nkux)

- [x] 1.1 Host-blok `nixosConfigurations.mpenzi` in `flake.nix` (alleen unstable-arg + agenix). Controle: `nix eval .#nixosConfigurations.mpenzi.config.networking.hostName` geeft `"mpenzi"`.
- [x] 1.2 `hosts/mpenzi/hardware-configuration.nix` en `configuration.nix` met de swap-LUKS-regel, systemd-boot, NetworkManager, pipewire, nl_NL, us-intl, avahi, fwupd, wekelijkse gc. Controle: eval van `boot.initrd.luks.devices` toont beide LUKS-volumes.
- [x] 1.3 Gebruikers maaike/wtoorren/sysadmin en ssh alleen met sleutel. Controle: eval van de groepen en sshd-settings (zie 5.2).

## 2. Plasma en apps (bean nixos-v0p3)

- [x] 2.1 Plasma 6 + SDDM en `/etc/xdg`-defaults (kdeglobals, kglobalshortcutsrc). Controle: de bestanden staan in `etc` van de build.
- [x] 2.2 Apps, fonts, Canva/Jitsi-webapps, Nextcloud-autostart, Flatpak + Flathub-oneshot, Discover, printer-module. Controle: build slaagt, geen insecure pakket.

## 3. Nebula (bean nixos-e41o)

- [x] 3.1 `modules/nebula.nix` met hosts-tabel, agenix-secrets, pathExists-gate en warning. Controle: eval op de drie hosts toont de warning en geen nebula-service.
- [x] 3.2 Import op malandro, lobos en mpenzi; entries in `secrets/secrets.nix`. Controle: `nixos-rebuild dry-build --flake .#malandro` en eval `.#lobos` slagen.
- [x] 3.3 VM-test `checks.x86_64-linux.nebula`. Controle: `nix build .#checks.x86_64-linux.nebula -L` slaagt.

## 4. RustDesk (bean nixos-silu)

- [x] 4.1 RustDesk-service met direct-server-seed op mpenzi. Controle: eval toont `systemd.services.rustdesk` met `--service`.
- [x] 4.2 `rustdesk-flutter` op lobos. Controle: eval van lobos-systemPackages bevat rustdesk.

## 5. Verificatie en documentatie

- [x] 5.1 `nix build .#nixosConfigurations.mpenzi.config.system.build.toplevel` slaagt.
- [x] 5.2 Acceptatie-eval: maaike niet in wheel, wtoorren wel met key, ssh alleen key-auth, geen autoUpgrade.
- [x] 5.3 `docs/mpenzi.md` + indexregel in `CLAUDE.md`; handmatige stappen in bean nixos-w4ci bijgewerkt.

## Workflow follow-up

- Archiveren met `openspec archive mpenzi-laptop` en committen.
