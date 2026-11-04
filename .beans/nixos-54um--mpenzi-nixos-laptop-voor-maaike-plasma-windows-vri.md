---
# nixos-54um
title: 'mpenzi: NixOS-laptop voor Maaike (Plasma, Windows-vriendelijk, Nebula + RustDesk)'
status: in-progress
type: epic
priority: normal
created_at: 2026-11-04T16:26:56Z
updated_at: 2026-11-04T16:32:21Z
---

Nieuwe NixOS-laptop **mpenzi** voor Maaike, die net van Windows overstapt. Een eigen, kaal host-blok
in de flake (model: `karlapi`), dus NIET de lobos-desktop (geen Hyprland, geen `extraPkgs`, geen
lobos-overlays, geen standalone home-manager).

Uitgewerkt in een `/opsx:explore`-sessie op 2026-11-04. Maak bij uitvoering een OpenSpec change
(voorstel: `mpenzi-laptop`) en werk de child-beans af.

## Besloten

| Onderwerp     | Keuze                                                                                       |
|---------------|---------------------------------------------------------------------------------------------|
| Basis         | NixOS 26.05, Plasma 6 + SDDM, systemd-boot, LUKS (root + swap), hostnaam `mpenzi`          |
| Taal          | `i18n.defaultLocale = "nl_NL.UTF-8"` (alle LC_* nl_NL), tijdzone Europe/Amsterdam           |
| Toetsenbord   | `us`, variant `intl` (dead keys, zoals Windows US-International)                            |
| Gebruikers    | `maaike` (description "Maaike", GEEN wheel, wel networkmanager/lp/scanner), `wtoorren` (wheel + ssh-key `wtoorren` uit `secrets/secrets.nix`). `sysadmin` blijft voorlopig staan, verdwijnt pas in een handmatige stap |
| Plasma        | Windows-achtige defaults via `/etc/xdg` (systeem-defaults, gebruiker mag overschrijven); GEEN plasma-manager/home-manager |
| Apps          | Firefox (default), Google Chrome, onlyoffice-desktopeditors + corefonts + vista-fonts, nextcloud-client (autostart), thunderbird, jitsi-meet-electron, zoom-us, bitwarden-desktop, Canva als webapp-desktopentry, rustdesk-flutter |
| Zelf installeren | Discover + Flatpak met Flathub                                                           |
| Printers      | `modules/printer-thuis.nix` importeren                                                       |
| Remote access | Nebula-mesh (altijd aan): lighthouse = malandro, nodes = lobos + mpenzi. RustDesk via Nebula-IP (direct IP, geen publieke relay) |
| Updates       | Handmatig door Wouter vanaf lobos: `nixos-rebuild switch --flake .#mpenzi --target-host wtoorren@mpenzi --sudo`. Geen autoUpgrade |
| Niet          | Kup, Skanpage, home-manager, autoUpgrade                                                     |

## Hardware (overgenomen van de laptop, `nixos-generate-config`)

```nix
boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
boot.kernelModules = [ "kvm-amd" ];
fileSystems."/" = { device = "/dev/mapper/luks-b1fa5503-292a-474c-ba08-8358d4b06242"; fsType = "ext4"; };
boot.initrd.luks.devices."luks-b1fa5503-292a-474c-ba08-8358d4b06242".device = "/dev/disk/by-uuid/b1fa5503-292a-474c-ba08-8358d4b06242";
fileSystems."/boot" = { device = "/dev/disk/by-uuid/47CC-A5BA"; fsType = "vfat"; options = [ "fmask=0077" "dmask=0077" ]; };
swapDevices = [ { device = "/dev/mapper/luks-ef7880b0-64cd-4dbb-8fa8-56faceca9e77"; } ];
hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
# imports: (modulesPath + "/installer/scan/not-detected.nix")
```

LET OP: deze regel stond in de originele `configuration.nix` (niet in hardware-configuration) en MOET mee,
anders boot de swap niet:

```nix
boot.initrd.luks.devices."luks-ef7880b0-64cd-4dbb-8fa8-56faceca9e77".device = "/dev/disk/by-uuid/ef7880b0-64cd-4dbb-8fa8-56faceca9e77";
```

`system.stateVersion = "26.05";`

## Grenzen voor de agent (draait op malandro)

- GEEN `nixos-rebuild switch`/`boot` op welke host dan ook; de gebruiker draait zelf. Alleen `build`/`dry-build`/eval.
- GEEN Nebula-CA of private keys genereren of committen; dat is een handmatige bean.
- Beans met tag `handmatig` NIET uitvoeren; laat ze op `todo` staan.

## Acceptatiecriteria

- `nix build .#nixosConfigurations.mpenzi.config.system.build.toplevel` slaagt.
- `nixos-rebuild dry-build --flake .#malandro` en een eval van `.#lobos` slagen met Nebula erbij.
- `maaike` zit niet in `wheel`; `wtoorren` wel, met de ssh-key; `services.openssh` staat aan, alleen key-auth.
- Nebula-firewall laat ssh (22) en RustDesk (21118) op mpenzi alleen toe vanaf lobos.
- OpenSpec change gearchiveerd, docs in `docs/mpenzi.md` + indexregel in `CLAUDE.md`.
