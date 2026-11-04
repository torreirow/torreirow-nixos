# Proposal

## Why

Maaike stapt over van Windows naar Linux. Haar laptop (**mpenzi**) moet een NixOS-host in deze
repo worden: eenvoudig en Windows-vertrouwd voor haar, en voor Wouter op afstand te beheren en te
ondersteunen. Dat moet zonder een publieke RustDesk-relay en zonder dat Maaike beheerrechten
heeft.

## What Changes

- Nieuw kaal host-blok `nixosConfigurations.mpenzi` (alleen `unstable`-arg + agenix, geen
  extraPkgs/overlays/home-manager) met `hosts/mpenzi/`: hardware (LUKS root + swap), Plasma 6 +
  SDDM, nl_NL, toetsenbord us-intl, gebruikers maaike (geen wheel) en wtoorren (wheel + ssh-key),
  ssh alleen met sleutel.
- Plasma-defaults als systeemlaag in `/etc/xdg` (dubbelklik, Win+E, Win+L, Win+Shift+S, Firefox
  als browser); Maaike kan alles zelf overschrijven.
- Apps: Firefox, Chrome, OnlyOffice + MS-fonts, Nextcloud (autostart), Thunderbird, Zoom,
  Bitwarden, Canva en Jitsi als Chrome-webapp, Discover + Flathub. Printers via
  `modules/printer-thuis.nix`.
- Nieuwe gedeelde module `modules/nebula.nix`: mesh `toorren` op 10.77.0.0/24, lighthouse en relay
  malandro (UDP 4242), nodes lobos en mpenzi. Op mpenzi mag alleen lobos tcp 22 en 21118 bereiken.
  Nebula blijft uit zolang de certificaten (agenix) ontbreken.
- RustDesk op mpenzi als systeemservice met direct IP access; RustDesk-pakket op lobos.
- VM-test `checks.x86_64-linux.nebula` voor het toegangsbeleid.

## Capabilities

### New Capabilities

- `mpenzi-host`: de laptop-host mpenzi: gebruikers en rechten, ssh-toegang, taal/toetsenbord,
  bureaublad-defaults, apps en beheer op afstand vanaf lobos.
- `nebula-mesh`: het overlay-netwerk tussen malandro, lobos en mpenzi en het toegangsbeleid
  daarop.
- `remote-support`: meekijken op mpenzi met RustDesk via het overlay-netwerk, zonder publieke
  relay.

### Modified Capabilities

(geen)

## Impact

- `flake.nix` (host-blok mpenzi, check nebula), `hosts/mpenzi/*`, `modules/nebula.nix`,
  `modules/nebula_vmtest.nix`.
- lobos en malandro importeren `modules/nebula.nix`; lobos krijgt `rustdesk-flutter`.
- Handmatig (bean nixos-w4ci): eerste deploy, host-key, Nebula-CA en certs, router UDP 4242,
  wachtwoorden, sysadmin weghalen.
