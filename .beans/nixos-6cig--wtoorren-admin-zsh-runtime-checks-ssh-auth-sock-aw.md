---
# nixos-6cig
title: 'wtoorren-admin: zsh runtime-checks (SSH_AUTH_SOCK, ~/.aws/credentials)'
status: completed
type: task
priority: normal
created_at: 2026-11-04T20:39:33Z
updated_at: 2026-11-04T22:03:45Z
parent: nixos-tesy
blocked_by:
    - nixos-xa9h
---

zsh-gedrag per host op runtime.

- `SSH_AUTH_SOCK` naar `$XDG_RUNTIME_DIR/rbw/ssh-agent-socket` alleen als `$SSH_CONNECTION` leeg is.
  Geldt voor het profiel; voor lobos (`home/zsh.nix`, `home/sshkeys.nix`) gedrag ongewijzigd laten.
- bmc-wrapperfunctie, `bmcp`, `aws-switch`, `tfplan`/`tfapply`/`tfbackend` alleen definiëren als
  `[[ -f ~/.aws/credentials ]]`.
- Prompt/tmux-labels voor rbw-profiel (`active-profile`) moeten ook werken als `~/.config/rbw/active-profile` ontbreekt.


## Summary of Changes

`SSH_AUTH_SOCK` naar rbw alleen zonder `$SSH_CONNECTION` (base.nix); bmc-functie en bmcp/aws-switch/tfplan/tfapply/tfbackend alleen met `~/.aws/credentials` (aws.nix); active-profile is optioneel. lobos (zsh.nix/sshkeys.nix) ongewijzigd. VM-test dekt alle drie.
