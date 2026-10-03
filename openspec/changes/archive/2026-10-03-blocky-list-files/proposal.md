## Why

De blocky-configuratie groeit: eigen domeinlijsten (zoals een toekomstige `block-boaz`) als
inline YAML-blobs in `modules/blocky.nix` maken het bestand snel onoverzichtelijk, en elke
lijstwijziging vereist een volledige `nixos-rebuild`. We willen (1) de lijsten als platte,
reviewbare tekstbestanden in git, én (2) een snelle, mutabele route om af en toe iets toe te
voegen of vrij te geven zonder rebuild. blocky 0.35 ondersteunt beide native: een denylist/
allowlist-groep neemt **meerdere bronnen** (bestand én directory) en voegt ze samen.

## What Changes

- **Nix opsplitsen (leesbaarheid):** `modules/blocky.nix` → directory-module
  `modules/blocky/` met `default.nix` (service, container, nginx, secrets, render-pipeline) en
  `blocking.nix` (denylists/allowlists/clientGroupsBlock/schedules/listSchedules), plus een map
  `modules/blocky/lists/` met platte domeinlijsten (hosts-formaat).
- **Declaratieve baseline + mutabele overlay per groep.** Elke eigen groep verwijst naar twee
  bronnen: een baseline-bestand uit de repo (`./lists/<groep>.txt`, in git) én een mutabele
  overlay-directory onder `/data/external/blocky/denylists.d/<groep>/`. Analoog een allowlist-
  overlay onder `/data/external/blocky/allowlists.d/<groep>/` om live te kunnen de-blokkeren.
- **Overlay-dirs via tmpfiles** (`root:root 0755`, bewerken met `sudo`). blocky leest ze read-only
  — werkt onder `DynamicUser` + `ProtectSystem=strict`, dus geen StateDirectory-verhuizing en geen
  bind-mounts nodig. StateDirectory blijft ongemoeid (blocky is stateless).
- **Refresh-helper** `blocky-refresh`: `curl -X POST http://127.0.0.1:4000/api/lists/refresh` →
  overlay-wijzigingen direct actief, zonder restart of rebuild (blocky's `loading.refreshPeriod`
  pikt het anders vanzelf op).
- **Backup:** `/data/external/blocky` toevoegen aan de rustic-manifest, zodat live-bewerkte
  overlays een restore overleven (de baseline zit al in git).

## Capabilities

### Modified Capabilities

- `blocky-dns`: denylists/allowlists worden uit bestanden geladen (baseline uit de repo) en per
  groep aangevuld met een mutabele overlay-directory op `/data/external/blocky`, live herlaadbaar
  via `blocky-refresh`. Nix wordt opgesplitst in een directory-module voor leesbaarheid.
- `rustic-backup`: `/data/external/blocky` toegevoegd aan de backup-manifest.

## Impact

- `modules/blocky.nix` → `modules/blocky/default.nix` + `modules/blocky/blocking.nix`
- `modules/blocky/lists/*.txt` — nieuw (platte baseline-domeinlijsten)
- `hosts/malandro/configuration.nix` — import `../../modules/blocky.nix` → `../../modules/blocky`
- `modules/rustic-backup.nix` — `/data/external/blocky` aan `backupSources`
- `systemd.tmpfiles` — overlay-dirs `/data/external/blocky/{denylists.d,allowlists.d}/<groep>`
- Nieuwe helper `blocky-refresh` in `environment.systemPackages` (of als script)
- Geen datamigratie; blocky herstart bij de switch en herlaadt alle bronnen
