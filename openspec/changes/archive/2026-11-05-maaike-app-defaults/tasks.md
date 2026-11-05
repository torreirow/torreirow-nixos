# Tasks

## 1. HM-profiel en policies (bean nixos-8tac)

- [x] 1.1 wtoorren-admin: nixvim van `sharedModules` naar `users.wtoorren.imports`. Controle: drvPath van wtoorrens HM-generatie op mpenzi gelijk.
- [x] 1.2 `modules/maaike-apps.nix` met `toorren.maaike.enable`; `home/profiles/maaike/default.nix`; mpenzi zet het aan.
- [x] 1.3 Firefox/Chrome-extensies en Thunderbird-policy in `hosts/mpenzi/apps.nix`.

## 2. Seeds en herstel-app (bean nixos-nuty)

- [x] 2.1 `home/profiles/maaike/seeds.nix`: Nextcloud, Bitwarden, ZapZap, SMPlayer + `seed-apps`.
- [x] 2.2 `herstel-app` (incl. spotify en signal); SMPlayer-tmpfiles weg.

## 3. Spotify via agenix (bean nixos-s5g5)

- [x] 3.1 Optie `toorren.maaike.spotifyPrefs`, `age.secrets.spotify-maaike` met pad/owner/mode, tmpfiles voor `~/.config/spotify`, warning zonder bestand.

## 4. Vastleggen, test en docs (bean nixos-h295)

- [x] 4.1 `scripts/vastleggen-app-defaults.sh` (ssh, filter, diff, bevestigen).
- [x] 4.2 VM-test `checks.x86_64-linux.maaike-apps`: seeds, tweede activatie, herstel-app nextcloud/foutmelding.
- [x] 4.3 Builds/evals: mpenzi toplevel, policies, age-secret, maaike zonder nixvim/plasma-manager.
- [x] 4.4 `docs/maaike-app-defaults.md` + indexregel `CLAUDE.md`, `docs/mpenzi.md`, CHANGELOG.
