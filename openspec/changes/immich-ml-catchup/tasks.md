## 1. Implementatie

- [x] 1.1 `modules/immich-ml-catchup/catchup.sh` + `package.nix` (writeShellApplication)
- [x] 1.2 `modules/immich-ml-catchup/default.nix`: oneshot-dienst + timer (10 min), LoadCredential, aan alleen als het secret bestaat
- [x] 1.3 Import in `hosts/malandro/configuration.nix`, regel in `secrets/secrets.nix`

## 2. Testen

- [x] 2.1 Flake-check `immich-ml-catchup`: ML down, ML terug, binnen/na MAX_AGE, "already running", foute sleutel
- [x] 2.2 malandro bouwt zonder sleutel (warning) en met een dummy-sleutel (timer + dienst aanwezig)

## 3. Documentatie

- [x] 3.1 `docs/immich.md`: inhaal-timer, sleutel aanmaken en versleutelen

## 4. Uitrol (handmatig)

- [ ] 4.1 API-sleutel aanmaken (admin, alleen `job.create`) en versleutelen naar `secrets/immich-ml-catchup-key.age`
- [ ] 4.2 malandro rebuilden; `systemctl start immich-ml-catchup` → "Missing gestart" in de journal
