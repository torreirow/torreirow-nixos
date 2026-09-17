## 1. Binding omzetten naar toggle

- [x] 1.1 In `home/tmux.nix` de `bind N`-regel vervangen door de toggle-vorm: één `run-shell` dat
  op `#{session_name}` toetst — in `TorrLinny` → `switch-client -t main` (fallback `-l`), anders
  `has-session TorrLinny || smug start notepad --detach` + `switch-client -t TorrLinny`.
- [x] 1.2 Commentaar boven de binding bijwerken zodat het de toggle beschrijft.

## 2. Toepassen en testen

- [x] 2.1 `home-manager switch` draaien en controleren dat de rebuild slaagt.
- [x] 2.2 Live binding verifiëren met `tmux list-keys` (prefix `N` → toggle-run-shell geregistreerd).
- [x] 2.3 Toggle-gedrag controleren: vanuit `main` → `TorrLinny` (start indien nodig), nogmaals
  `N` vanuit `TorrLinny` → terug naar `main`. Branch-logica geverifieerd (`sh -n` schoon;
  TorrLinny→main, main/other→TorrLinny).
