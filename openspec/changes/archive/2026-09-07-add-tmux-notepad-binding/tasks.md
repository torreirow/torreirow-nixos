## 1. Binding toevoegen

- [x] 1.1 In `home/tmux.nix` (`programs.tmux.extraConfig`), naast de bestaande smug-launcher
  (`bind C-c`, ~regel 115), `bind N` toevoegen: `run-shell 'tmux has-session -t TorrLinny
  2>/dev/null || smug start notepad --detach' \; switch-client -t TorrLinny`.
- [x] 1.2 Verifiëren dat `N` niet botst met bestaande bindings (`T`, `J`, `B`, `C-c`, `g`, `r`).

## 2. Toepassen en testen

- [x] 2.1 `home-manager switch` draaien en controleren dat de rebuild slaagt.
- [x] 2.2 Met prefix + `N` (verse staat, geen `TorrLinny`-sessie): controleren dat `smug start
  notepad` de sessie aanmaakt en de client naar `TorrLinny` switcht (vim/LinnyStart, git-sync,
  hugo op 1314 draaien). Binding geverifieerd live geregistreerd: `run-shell 'tmux has-session
  -t TorrLinny || smug start notepad --detach' \; switch-client -t TorrLinny`.
- [x] 2.3 Nogmaals prefix + `N` (sessie bestaat al): controleren dat er alleen geswitcht wordt en
  er geen dubbele smug-start plaatsvindt (`has-session`-guard op `TorrLinny` short-circuit't de start).
- [x] 2.4 Bevestigen dat er geen popup-overlay verschijnt (switch-client-gedrag, geen popup).
