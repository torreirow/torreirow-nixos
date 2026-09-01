---
# nixos-bf5j
title: 'Spike: accepteert nextcloudcmd --netrc een custom pad?'
status: completed
type: task
priority: high
created_at: 2026-08-31T10:50:05Z
updated_at: 2026-08-31T10:52:55Z
parent: nixos-3es6
---

Spike voltooid via `nix shell nixpkgs#nextcloud-client -c nextcloudcmd --help`.

## Uitkomst
- `-n` (netrc) leest HARDCODED `~/.netrc` — GEEN flag voor custom pad. Smaak-A-idee "netrc in ~/.config" werkt dus niet direct met -n.
- **`--non-interactive` leest `$NC_USER` en `$NC_PASSWORD` uit de environment.** Dit is de schone route voor een systemd-service.

## Besluit (vervangt netrc-aanpak)
Auth via `--non-interactive` + systemd `EnvironmentFile=%h/.config/nextcloud-sync/credentials` met regels `NC_USER=...` en `NC_PASSWORD=<app-password>`. Bestand handmatig, 0600, in ~/.config (zoals gewenst), niet in nix-store.

Invocatie: `nextcloudcmd --non-interactive [--path /remote] [--confdir <state>] <local_dir> <server_url>`.
Relevante flags: `--path` (remote subfolder), `--confdir` (eigen state-dir), `--exclude`, `--trust`, `--silent`.
