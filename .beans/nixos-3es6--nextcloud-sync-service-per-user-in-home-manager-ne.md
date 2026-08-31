---
# nixos-3es6
title: Nextcloud sync-service per user in home-manager (nextcloudcmd + timer)
status: completed
type: epic
priority: normal
created_at: 2026-08-31T10:49:12Z
updated_at: 2026-08-31T11:00:58Z
---

Epic voltooid. Home-manager module voor headless Nextcloud-sync per user, geïmplementeerd, getest en gedocumenteerd. OpenSpec-change gearchiveerd als 2026-08-31-add-nextcloud-sync; main-spec openspec/specs/nextcloud-sync/spec.md.

## Summary of Changes
- **home/module/nextcloud-sync/default.nix** — nieuwe module `services.nextcloud-sync`. Per `syncs.<naam>` een oneshot `systemd.user.service` + `systemd.user.timer` die `nextcloudcmd` draait.
- **Auth (spike-uitkomst nixos-bf5j):** `-n`/netrc leest hardcoded `~/.netrc` (geen custom pad) → vervangen door `--non-interactive` dat `$NC_USER`/`$NC_PASSWORD` uit de env leest, via `EnvironmentFile=-<credentialsFile>` (default `~/.config/nextcloud-sync/credentials`, handmatig, 0600). Credential nooit in nix-store/git.
- **Timer:** `OnUnitActiveSec=<interval>` (default 10min, geen overlap) + `OnActiveSec=2min`.
- **Path-handling:** leidende `~/` geëxpandeerd; per-sync `--confdir` state-dir; `ExecStartPre` valideert credentials + `mkdir -p` local/state met nette foutmelding.
- **home/module/nextcloud-sync/README.md** — docs incl. app-password-instructie en expliciete waarschuwing tegen `home.file.text` (nix-store-lek).
- **flake.nix** — module-import in `wtoorren@linuxdesktop`.
- **CHANGELOG.md** — entry onder NEXT VERSION.

## Verificatie
- `nextcloudcmd --help` (spike) bevestigt `--non-interactive` env-vars.
- `nix eval` default (`enable=false`) schoon; `extendModules` met 2 sync-paren → correcte ExecStart/timer/EnvironmentFile.
- `nix build` van de volledige activationPackage → end-to-end succesvol.
- `openspec validate add-nextcloud-sync` → valid.

## Activatie (handmatige stap, by design)
`enable = false` in de gecommitte config. Om te activeren: maak `~/.config/nextcloud-sync/credentials` (0600) met NC_USER/NC_PASSWORD (Nextcloud app-password), zet `services.nextcloud-sync.enable = true` + een `syncs`-entry, en `home-manager switch`.
