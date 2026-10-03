## 1. Nix-structuur opsplitsen (directory-module)

- [x] 1.1 Maak `modules/blocky/` aan; verplaats de inhoud van `modules/blocky.nix` naar
      `modules/blocky/default.nix`
- [x] 1.2 Splits de `blocking`-settings af naar `modules/blocky/blocking.nix` (levert een attrset
      dat `default.nix` in `blockyBaseSettings.blocking` opneemt, bv. via `import ./blocking.nix`)
- [x] 1.3 Maak `modules/blocky/lists/` met platte baseline-domeinlijsten (hosts-formaat, één
      domein per regel). (`ads` blijft als URL-bronnen; dit betreft eigen domeinlijsten.)
- [x] 1.4 Wijzig de import in `hosts/malandro/configuration.nix` van `../../modules/blocky.nix`
      naar `../../modules/blocky`
- [x] 1.5 Verwijder het oude `modules/blocky.nix`

## 2. Baseline + mutabele overlay per groep

- [x] 2.1 In `blocking.nix`: per eigen denylist-groep twee bronnen —
      `./lists/<groep>.txt` (baseline) + `"/data/external/blocky/denylists.d/<groep>.txt"`
      (overlay). LET OP: blocky accepteert als bron alleen een BESTAND, geen directory/glob
      (runtime-fout "is a directory" / "cannot open '*'"), dus één overlay-bestand per groep.
- [x] 2.2 Per groep een allowlist-overlay-bestand: `"/data/external/blocky/allowlists.d/<groep>.txt"`
- [x] 2.3 `systemd.tmpfiles.rules`: de dirs (`d`) `+ denylists.d/allowlists.d`, en per groep een
      **leeg bestand** (`f /data/external/blocky/denylists.d/<groep>.txt 0644 root root -`, idem allow)
- [x] 2.4 Geverifieerd: blocky leest `/data/external/blocky` prima onder `DynamicUser` +
      `ProtectSystem=strict` (bereikte de bestanden; geen `ReadOnlyPaths` nodig)

## 3. Refresh-helper

- [x] 3.1 Voeg `blocky-refresh` toe (script in `environment.systemPackages` of `writeShellScriptBin`):
      `curl -fsS -X POST http://127.0.0.1:4000/api/lists/refresh` (toont HTTP-status, geen `|| true`)

## 4. Backup

- [x] 4.1 Voeg `/data/external/blocky` toe aan `backupSources` in `modules/rustic-backup.nix`

## 5. Deployen en testen

- [x] 5.1 `nix-instantiate --parse` op de nieuwe modules; `nixos-rebuild build --flake .#malandro`
      en inspecteer de gerenderde blocky-config (baseline- + overlay-paden aanwezig)
- [x] 5.2 `sudo nixos-rebuild switch --flake .#malandro`; blocky + blocky-ui blijven draaien
- [x] 5.3 Overlay-test: zet een testdomein in `/data/external/blocky/denylists.d/<groep>/test.txt`
      (`sudo`), draai `blocky-refresh`, en bevestig dat het domein geblokkeerd wordt zonder rebuild
- [x] 5.4 Allowlist-test: zet datzelfde domein in de allowlist-overlay, `blocky-refresh`, en
      bevestig dat het weer resolveert (live de-blokkeren werkt)
- [x] 5.5 Baseline-test: een domein in de repo-`.txt` wordt na switch geblokkeerd
- [x] 5.6 Backup-check: `/data/external/blocky` zit in de rustic-manifest (eval of dry-run)
