---
# nixos-xa9h
title: 'wtoorren-admin: profiel base.nix uit bestaande home-modules'
status: todo
type: task
created_at: 2026-11-04T20:39:33Z
updated_at: 2026-11-04T20:39:33Z
parent: nixos-tesy
---

Profiel opsplitsen zonder lobos te breken.

- `home/profiles/wtoorren-admin/base.nix`: zsh, tmux, nixvim, rbw (+ de twee rbw config.json's),
  atuin/fzf/direnv/jq. Haal de bruikbare delen uit `home/zsh.nix`, `home/tmux.nix`, `home/common.nix`,
  `home/dotfiles/default.nix`; liefst door die bestanden te laten importeren/delen i.p.v. te kopiëren.
- Niet meenemen: `codevibing/claude.nix`, Strawberry/subtitleedit/toggl, `ssh-config_hosts`,
  `vaultwarden-restore-test`, `wake-bobadela1`, `clipbridge`, `update-system`, seahorse-askpass.
- Hardcoded paden naar `~/data/git/wearetechnative/*` alleen in het aws-deel en alleen als ze bestaan.
- `home.stateVersion` komt van de host (NixOS-module zet hem op `config.system.stateVersion`).
