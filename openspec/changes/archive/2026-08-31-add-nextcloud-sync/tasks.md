# Tasks — add-nextcloud-sync

## 1. Spike (bean nixos-bf5j)
- [x] 1.1 `nextcloudcmd --help` onderzocht: `-n` leest hardcoded `~/.netrc` (geen custom pad)
- [x] 1.2 Vastgesteld dat `--non-interactive` `$NC_USER`/`$NC_PASSWORD` uit de env leest
- [x] 1.3 Ontwerpbesluit: EnvironmentFile i.p.v. netrc (spike-uitkomst genoteerd op de bean)

## 2. Module (bean nixos-axoq)
- [x] 2.1 `home/module/nextcloud-sync/default.nix` met `services.nextcloud-sync`
- [x] 2.2 Options: `enable`, `package`, `credentialsFile`, `syncs.<naam>` (submodule)
- [x] 2.3 Path-normalisatie voor leidende `~/`
- [x] 2.4 `home/module/nextcloud-sync/README.md`

## 3. Systemd service (bean nixos-jx75)
- [x] 3.1 Oneshot `nextcloud-sync-<naam>.service` per sync-paar
- [x] 3.2 `ExecStart=nextcloudcmd --non-interactive --silent [--trust] [--path R] --confdir S <local> <url>`
- [x] 3.3 `EnvironmentFile=-<credentialsFile>` (optioneel-prefix)
- [x] 3.4 `ExecStartPre`: valideer credentials + `mkdir -p` local + state-dir, nette foutmelding

## 4. Systemd timer (bean nixos-tjfn)
- [x] 4.1 `nextcloud-sync-<naam>.timer` per sync-paar
- [x] 4.2 `OnUnitActiveSec=<interval>` (default 10min) + `OnActiveSec=2min`
- [x] 4.3 `WantedBy=timers.target`

## 5. Package (bean nixos-f7di)
- [x] 5.1 `pkgs.nextcloud-client` via de module aan `home.packages` (bij `enable`)

## 6. Credentials + docs (bean nixos-xml4)
- [x] 6.1 `credentials.example` (placeholders) neergezet via de module
- [x] 6.2 README: app-password, 0600, waarschuwing tegen `home.file.text` (nix-store-lek)

## 7. Wiring (bean nixos-ur19)
- [x] 7.1 Module-import toegevoegd aan `flake.nix` (`wtoorren@linuxdesktop`)
- [x] 7.2 Geverifieerd: `nix eval` (default + enabled via extendModules) en `nix build` van de activationPackage
