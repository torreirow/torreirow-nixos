---
# nixos-bupo
title: 'wtoorren-admin: handmatig deployen en controleren op mpenzi'
status: todo
type: task
priority: normal
tags:
    - handmatig
created_at: 2026-11-04T20:39:33Z
updated_at: 2026-11-04T20:52:08Z
parent: nixos-tesy
blocked_by:
    - nixos-682w
---

NIET door de agent.

1. Deploy mpenzi vanaf lobos: `command nixos-rebuild switch --flake .#mpenzi --target-host wtoorren@10.77.0.3 --sudo --ask-sudo-password`.
   Let op: `command`, anders maakt de alias er `sudo nixos-rebuild` van en vindt root de ssh-sleutel niet.
2. `ssh wtoorren@10.77.0.3`: zsh, tmux, nvim, `rbw unlock` werken; `type bmc` geeft geen functie; `ls ~/.aws/config` bestaat niet.
3. Later per server beslissen of het profiel daar aan gaat (malandro: eerst standalone HM uitfaseren).


4. nixhost: inloggen met ssh, dan `home-manager switch --flake .#wtoorren@admin -b backup`; controleer `rbw unlock`, `bmc` met MFA (`rbw code`), en dat de TOTP-code via tmux/OSC 52 op het clipboard van lobos komt.
