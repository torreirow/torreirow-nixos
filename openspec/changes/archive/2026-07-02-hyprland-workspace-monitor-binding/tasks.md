## 1. Workspace-monitor binding in default.nix

- [x] 1.1 Voeg `workspace` binding toe voor WS 1 → extern (default, persistent)
- [x] 1.2 Voeg `workspace` binding toe voor WS 2 → eDP-1 (default, persistent)
- [x] 1.3 Voeg `workspace` binding toe voor WS 3 → eDP-1 (persistent)
- [x] 1.4 Voeg `workspace` binding toe voor WS 4 → extern (persistent)
- [x] 1.5 Voeg `workspace` bindings toe voor WS 5-10 (persistent)

## 2. App-naar-workspace windowrules in windows.nix

- [x] 2.1 Voeg windowrule toe: Slack → workspace 3 silent
- [x] 2.2 Voeg windowrule toe: teams-for-linux → workspace 3 silent
- [x] 2.3 Voeg windowrule toe: Firefox → workspace 4 silent

## 3. Dynamische workspace-binder service

- [x] 3.1 `workspace-binder` script toegevoegd aan wayle.nix (detecteert eerste niet-eDP-1 monitor)
- [x] 3.2 Systemd user service `hyprland-workspace-binder` aangemaakt
- [x] 3.3 `wsbind` + `moveworkspacetomonitor` voor WS 1,4,6,8,10 → extern
- [x] 3.4 `sleep 1` na monitor-events voor betrouwbaar herbinden na lock/unlock

## 4. Verificatie

- [x] 4.1 `home-manager switch` uitgevoerd, service gestart
- [x] 4.2 Workspaces 1-10 zichtbaar en correct verdeeld over monitoren
